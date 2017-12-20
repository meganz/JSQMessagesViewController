
#import "MEGAToolbarAssetPicker.h"

#import "UIColor+MNZCategory.h"

NSString *CELL_ID = @"Photo";
const CGFloat kCellSquareSize = 93.0f;
const CGFloat kCellInset = 1.0f;
const NSUInteger kCellRows = 3;
CGFloat kCollectionViewHeight;

@interface MEGAToolbarAssetPicker ()

@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, weak) id<MEGAToolbarAssetPickerDelegate> delegate;

@property (nonatomic) PHFetchResult *fetchResult;
@property (nonatomic) NSMutableArray *selectedAssetsArray;

@end

@implementation MEGAToolbarAssetPicker

#pragma mark - Initialization

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate {
    if (self = [super init]) {
        _collectionView = collectionView;
        _delegate = delegate;
        [self fetchAssets];
        _selectedAssetsArray = [NSMutableArray new];

        [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:CELL_ID];
        
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

- (void)resetSelection {
    self.selectedAssetsArray = [NSMutableArray new];
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
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
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
            playView.frame = CGRectMake(8.0f, kCellSquareSize-24.0f, 12.0f, 12.0f);
            [cell.backgroundView addSubview:playView];
            UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(21.0f, kCellSquareSize-25.0f, 48.0f, 15.0f)];
            durationLabel.text = [self stringFromTimeInterval:currentAsset.duration];
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
            [cell.contentView.subviews[0] removeFromSuperview];
        }
    } else {
        cell.backgroundView.layer.borderColor = [[UIColor mnz_redFF333A] CGColor];
        cell.backgroundView.layer.borderWidth = 2.0;
        cell.backgroundView.layer.opacity = 0.48;
        // Add checkmark:
        UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"white_checkmark"]];
        checkView.frame = CGRectMake(kCellSquareSize-24.0f, 7.0f, 12.0f, 12.0f);
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

#pragma mark - Utils

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    }
}

@end
