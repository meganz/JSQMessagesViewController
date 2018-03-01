
#import "MEGAToolbarAssetPicker.h"

#import "ChatVideoUploadQuality.h"

#import "NSString+MNZCategory.h"
#import "UIApplication+MNZCategory.h"
#import "UIColor+MNZCategory.h"

const CGFloat kCellSquareSize = 93.0f;
const CGFloat kCellInset = 1.0f;
const NSUInteger kCellRows = 3;
CGFloat kCollectionViewHeight;

@interface MEGAToolbarAssetPicker ()

@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, weak) id<MEGAToolbarAssetPickerDelegate> delegate;

@property (nonatomic) PHFetchResult *fetchResult;
@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;

@property (nonatomic) ChatVideoUploadQuality videoQuality;

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

        [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"assetCellId"];
        
        // Reload when returning to foreground:
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(reloadUI)
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
        
        kCollectionViewHeight = (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
        CGFloat newY = _collectionView.frame.origin.y - kCollectionViewHeight + _collectionView.frame.size.height;
        _collectionView.frame = CGRectMake(_collectionView.frame.origin.x, newY, _collectionView.frame.size.width, kCollectionViewHeight);
    }
    
    //TODO: Remove this code and the property when not limiting the amount of videos:
    NSNumber *videoQualityNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"ChatVideoQuality"];
    if (videoQualityNumber) {
        self.videoQuality = videoQualityNumber.unsignedIntegerValue;
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:@(ChatVideoUploadQualityMedium) forKey:@"ChatVideoQuality"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.videoQuality = ChatVideoUploadQualityMedium;
    }
    
    return self;
}

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
        cell.backgroundView.layer.borderColor = [[UIColor mnz_redFF333A] CGColor];
        cell.backgroundView.layer.borderWidth = 2.0;
        cell.backgroundView.layer.opacity = 0.48;
        // Add checkmark:
        UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"white_checkmark"]];
        checkView.frame = CGRectMake(kCellSquareSize-18.0f, 7.0f, 12.0f, 12.0f);
        [cell.contentView addSubview:checkView];
    }
    cell.backgroundColor = [UIColor mnz_redFF333A];
    
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.fetchResult.count;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.selectedAssetsArray indexOfObject:[self.fetchResult objectAtIndex:indexPath.row]] == NSNotFound) {
        //TODO: Remove this temporal limitation
        if (self.videoQuality < ChatVideoUploadQualityOriginal) {
            for (PHAsset *asset in self.selectedAssetsArray) {
                if (asset.mediaType == PHAssetMediaTypeVideo) {
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Please, send videos one by one" message:nil preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                    [[UIApplication mnz_visibleViewController] presentViewController:alertController animated:YES completion:nil];
                    return;
                }
            }
        }
        [self.selectedAssetsArray addObject:[self.fetchResult objectAtIndex:indexPath.row]];
    } else {
        [self.selectedAssetsArray removeObject:[self.fetchResult objectAtIndex:indexPath.row]];
    }
    [collectionView reloadItemsAtIndexPaths:@[indexPath]];
    [self.delegate assetPicker:self didChangeSelectionTo:self.selectedAssetsArray];
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

@end
