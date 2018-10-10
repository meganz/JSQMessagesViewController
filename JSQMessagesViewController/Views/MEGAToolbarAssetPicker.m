
#import "MEGAToolbarAssetPicker.h"

#import "PWProgressView.h"
#import "UIScrollView+EmptyDataSet.h"

#import "DevicePermissionsHelper.h"
#import "NSString+MNZCategory.h"
#import "UIColor+MNZCategory.h"
#import "UIImage+MNZCategory.h"

const CGFloat kCellSquareSize = 93.0f;
const CGFloat kCellInset = 1.0f;
const NSUInteger kCellRows = 3;
CGFloat kCollectionViewHeight;

@interface MEGAToolbarAssetPicker () <DZNEmptyDataSetSource, DZNEmptyDataSetDelegate>

@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, weak) id<MEGAToolbarAssetPickerDelegate> delegate;

@property (nonatomic) PHFetchResult *fetchResult;
@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;
@property (nonatomic) NSMutableDictionary <NSIndexPath *, NSNumber *> *requestIdIndexPathDictionary;
@property (nonatomic) NSMutableDictionary <NSIndexPath *, NSNumber *> *progressIndexPathDictionary;

@end

@implementation MEGAToolbarAssetPicker

#pragma mark - Initialization

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                   selectedAssetsArray:(NSMutableArray<PHAsset *> *)selectedAssetsArray
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate {
    if (self = [super init]) {
        _collectionView = collectionView;
        _delegate = delegate;
        [self fetchAssets];
        _selectedAssetsArray = selectedAssetsArray;
        _requestIdIndexPathDictionary = [[NSMutableDictionary alloc] init];
        _progressIndexPathDictionary = [[NSMutableDictionary alloc] init];

        [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"assetCellId"];
        _collectionView.emptyDataSetSource = self;
        _collectionView.emptyDataSetDelegate = self;
        
        // Reload when returning to foreground:
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(reloadUI)
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
        
        kCollectionViewHeight = (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
        CGFloat newY = _collectionView.frame.origin.y - kCollectionViewHeight + _collectionView.frame.size.height;
        _collectionView.frame = CGRectMake(_collectionView.frame.origin.x, newY, _collectionView.frame.size.width, kCollectionViewHeight);
    }
    return self;
}

#pragma mark - Private

- (void)setSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray {
    self.selectedAssetsArray = selectedAssetsArray;
    [self.collectionView reloadData];
}

- (void)fetchAssets {
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending:false]];
    _fetchResult = [PHAsset fetchAssetsWithOptions:fetchOptions];
}

- (void)reloadUI {
    [self fetchAssets];
    [self.collectionView reloadData];
}

- (void)requestedAsset:(PHAsset *)asset data:(id)data indexPath:(NSIndexPath *)indexPath info:(NSDictionary *)info {
    PHImageRequestID requestId = (PHImageRequestID) [self.requestIdIndexPathDictionary objectForKey:indexPath].intValue;
    [self.requestIdIndexPathDictionary removeObjectForKey:indexPath];
    [self.progressIndexPathDictionary removeObjectForKey:indexPath];
    if (data) {
        if ([self.selectedAssetsArray indexOfObject:[self.fetchResult objectAtIndex:indexPath.row]] == NSNotFound) {
            MEGALogInfo(@"[AP] Add asset %@ to selected array", asset.localIdentifier);
            [self.selectedAssetsArray addObject:[self.fetchResult objectAtIndex:indexPath.row]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate assetPicker:self didChangeSelectionTo:self.selectedAssetsArray];
        });
    } else {
        if ([info objectForKey:@"PHImageCancelledKey"]) {
            MEGALogInfo(@"[AP] Request asset %@ cancelled by the user, request id %d", asset.localIdentifier, requestId);
        } else {
            NSError *error = [info objectForKey:@"PHImageErrorKey"];
            MEGALogError(@"[AP] Request asset %@ failed with error %@", asset.localIdentifier, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate requestAssetFailedWithError:error];
            });
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[self.collectionView indexPathsForVisibleItems] containsObject:indexPath]) {
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        }
    });
}

- (void)progressHandlerWithProgress:(double)progress indexPath:(NSIndexPath *)indexPath error:(NSError *)error {
    PHImageRequestID requestId = (PHImageRequestID) [self.requestIdIndexPathDictionary objectForKey:indexPath].intValue;
    if (error) {
        MEGALogError(@"[AP] Progress handler for id %d failed with error %@", requestId, error);
    } else {
        MEGALogInfo(@"[AP] Progress %f for id %d", progress, requestId);
        
        [self.progressIndexPathDictionary setObject:@(progress) forKey:indexPath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
            if (cell) {
                [self drawAssetProgressInCell:cell indexPath:indexPath];
            }
        });
    }
}

- (void)drawAssetProgressInCell:(UICollectionViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    NSNumber *progress = [self.progressIndexPathDictionary objectForKey:indexPath];
    if (progress) {
        PWProgressView *progressView;
        if ([[cell.backgroundView.subviews lastObject] isKindOfClass:[PWProgressView class]]) {
            progressView = [cell.backgroundView.subviews lastObject];
        } else {
            progressView = [[PWProgressView alloc] initWithFrame:cell.backgroundView.frame];
            [cell.backgroundView addSubview:progressView];
        }
        progressView.progress = progress.doubleValue;
    } else {
        if ([[cell.backgroundView.subviews lastObject] isKindOfClass:[PWProgressView class]]) {
            [[cell.backgroundView.subviews lastObject] removeFromSuperview];
        }
    }
}

#pragma mark - UICollectionViewDataSource

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"assetCellId" forIndexPath:indexPath];
    
    // UIImage from PHAsset:
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES;
    PHAsset *currentAsset = [self.fetchResult objectAtIndex:indexPath.row];
    [[PHImageManager defaultManager] requestImageForAsset:currentAsset targetSize:CGSizeMake(kCellSquareSize, kCellSquareSize) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.backgroundView = [[UIImageView alloc] initWithImage:result];
        cell.backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        cell.backgroundView.layer.masksToBounds = YES;
        // Videos:
        if (currentAsset.mediaType == PHAssetMediaTypeVideo) {
            UIImageView *playView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"video_list"]];
            playView.frame = CGRectMake(2.0f, kCellSquareSize-17.0f, 12.0f, 12.0f);
            [cell.backgroundView addSubview:playView];
            UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, kCellSquareSize-17.5f, 48.0f, 15.0f)];
            durationLabel.text = [NSString mnz_stringFromTimeInterval:currentAsset.duration];
            durationLabel.font = [UIFont mnz_SFUIRegularWithSize:12.0f];
            durationLabel.textColor = [UIColor whiteColor];
            [cell.backgroundView addSubview:durationLabel];
        }
    }];
    
    // Custom style for selected assets:
    if ([self.selectedAssetsArray indexOfObject:[self.fetchResult objectAtIndex:indexPath.row]] == NSNotFound) {
        cell.backgroundView.layer.borderColor = nil;
        cell.backgroundView.layer.borderWidth = 0.0;
        cell.backgroundView.layer.opacity = 1.0;
        // Remove checkmark if needed:
        if (cell.contentView.subviews.count > 0) {
            for (UIView *checkView in cell.contentView.subviews) {
                [checkView removeFromSuperview];
            }
        }
    } else {
        cell.backgroundView.layer.borderColor = [UIColor.mnz_redMain CGColor];
        cell.backgroundView.layer.borderWidth = 2.0;
        cell.backgroundView.layer.opacity = 0.48;
        // Add checkmark:
        UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"white_checkmark"]];
        checkView.frame = CGRectMake(kCellSquareSize-18.0f, 7.0f, 12.0f, 12.0f);
        [cell.contentView addSubview:checkView];
    }
    
    cell.backgroundColor = UIColor.mnz_redMain;
    
    if ([self.requestIdIndexPathDictionary objectForKey:indexPath]) {
        [self drawAssetProgressInCell:cell indexPath:indexPath];
    }
    
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.fetchResult.count;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    __block PHImageRequestID requestId = (PHImageRequestID) [self.requestIdIndexPathDictionary objectForKey:indexPath].intValue;
    if (requestId) {
        [[PHImageManager defaultManager] cancelImageRequest:requestId];
        MEGALogInfo(@"[AP] Cancel image/video request id %d", requestId);
        [self.requestIdIndexPathDictionary removeObjectForKey:indexPath];
        [self.progressIndexPathDictionary removeObjectForKey:indexPath];
        return;
    }
    PHAsset *asset = [self.fetchResult objectAtIndex:indexPath.row];
    
    if ([self.selectedAssetsArray indexOfObject:asset] != NSNotFound) {
        MEGALogInfo(@"[AP] Remove asset %@ from selected array", asset.localIdentifier);
        [self.selectedAssetsArray removeObject:[self.fetchResult objectAtIndex:indexPath.row]];
        [self.delegate assetPicker:self didChangeSelectionTo:self.selectedAssetsArray];
        return;
    }
    
    switch (asset.mediaType) {
        case PHAssetMediaTypeImage: {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.version = PHImageRequestOptionsVersionCurrent;
            options.networkAccessAllowed = YES;
            options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                [self progressHandlerWithProgress:progress indexPath:indexPath error:error];
            };
            
            requestId = [[PHImageManager defaultManager]
                         requestImageDataForAsset:asset
                         options:options
                         resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                             [self requestedAsset:asset data:imageData indexPath:indexPath info:info];
                         }];
            
            MEGALogInfo(@"[AP] Request image data id %d, asset %@", requestId, asset.localIdentifier);
            
            break;
        }
            
        case PHAssetMediaTypeVideo: {
            PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
            options.version = PHImageRequestOptionsVersionOriginal;
            options.networkAccessAllowed = YES;
            options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                [self progressHandlerWithProgress:progress indexPath:indexPath error:error];
            };
            requestId = [[PHImageManager defaultManager]
                         requestAVAssetForVideo:asset
                         options:options resultHandler:^(AVAsset *data, AVAudioMix *audioMix, NSDictionary *info) {
                             [self requestedAsset:asset data:data indexPath:indexPath info:info];
                         }];
            
            MEGALogInfo(@"[AP] Request video id %d, asset %@", requestId, asset.localIdentifier);
            
            break;
        }
            
        default:
            break;
    }
    
    [self.requestIdIndexPathDictionary setObject:@(requestId) forKey:indexPath];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(kCellSquareSize, kCellSquareSize);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(kCellInset, kCellInset, kCellInset, kCellInset);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return kCellInset;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return kCellInset/2;
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSAttributedString *attributedString = nil;
    
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        NSString *text = AMLocalizedString(@"To share photos and videos, allow MEGA to access your photos", @"Detailed explanation of why the user should give permission to access to the photos");
        attributedString = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:[UIFont mnz_SFUIRegularWithSize:14.0f], NSForegroundColorAttributeName:UIColor.mnz_black333333}];
    }
    
    return attributedString;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    UIImage *image = nil;
    
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        image = [UIImage mnz_imageNamed:@"photosPermission" scaledToSize:CGSizeMake(120.0f, 120.0f)];
    }
    
    return image;
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    NSAttributedString *attributedString = nil;
    
    if ([PHPhotoLibrary authorizationStatus] != PHAuthorizationStatusAuthorized) {
        NSString *text = AMLocalizedString(@"Enable Access", @"Button which triggers a request for a specific permission, that have been explained to the user beforehand");
        attributedString = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName:[UIFont mnz_SFUISemiBoldWithSize:17.0f], NSForegroundColorAttributeName:UIColor.mnz_green899B9C}];
    }
    
    return attributedString;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return UIColor.whiteColor;
}

#pragma mark - DZNEmptyDataSetDelegate

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    [DevicePermissionsHelper alertPhotosPermission];
}

@end
