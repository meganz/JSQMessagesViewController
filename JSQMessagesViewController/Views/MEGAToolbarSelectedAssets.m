
#import "MEGAToolbarSelectedAssets.h"

#import "NSString+MNZCategory.h"

CGFloat kSelectedAssetCellSquareSize = 134.0f;

@interface MEGAToolbarSelectedAssets ()

@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, weak) id<MEGAToolbarAssetPickerDelegate> delegate;

@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;

@end

@implementation MEGAToolbarSelectedAssets

#pragma mark - Initialization

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                   selectedAssetsArray:(NSMutableArray<PHAsset *> *)selectedAssetsArray
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate {
    if (self = [super init]) {
        _collectionView = collectionView;
        _delegate = delegate;
        _selectedAssetsArray = selectedAssetsArray;
        
        [collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"selectedAssetCellId"];
        
        // Reload when returning to foreground:
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(reloadUI)
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    }
    return self;
}

- (void)setSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray {
    self.selectedAssetsArray = selectedAssetsArray;
    [self.collectionView reloadData];
    if (selectedAssetsArray.count > 0) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:self.selectedAssetsArray.count-1 inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:YES];
    }
}

- (void)reloadUI {
    [self.collectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"selectedAssetCellId" forIndexPath:indexPath];

    // UIImage from PHAsset:
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = YES;
    PHAsset *currentAsset = [self.selectedAssetsArray objectAtIndex:indexPath.row];
    [[PHImageManager defaultManager] requestImageForAsset:currentAsset targetSize:CGSizeMake(kSelectedAssetCellSquareSize, kSelectedAssetCellSquareSize) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.backgroundView = [[UIImageView alloc] initWithImage:result];
        cell.backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        cell.backgroundView.layer.masksToBounds = YES;
        cell.backgroundView.layer.cornerRadius = 4.0f;
        // Videos:
        if (currentAsset.mediaType == PHAssetMediaTypeVideo) {
            UIImageView *playView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"video_list"]];
            playView.frame = CGRectMake(8.0f, kSelectedAssetCellSquareSize-24.0f, 12.0f, 12.0f);
            [cell.backgroundView addSubview:playView];
            UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(21.0f, kSelectedAssetCellSquareSize-25.0f, 48.0f, 15.0f)];
            durationLabel.text = [NSString mnz_stringFromTimeInterval:currentAsset.duration];
            durationLabel.font = [UIFont mnz_SFUIRegularWithSize:12.0f];
            durationLabel.textColor = [UIColor whiteColor];
            [cell.backgroundView addSubview:durationLabel];
        }
        // Close:
        UIImageView *closeButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"remove_media"]];
        closeButton.frame = CGRectMake(kSelectedAssetCellSquareSize - 26.0f - 6.0f, 6.0f, 26.0f, 26.0f);
        [cell.backgroundView addSubview:closeButton];
    }];
    
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.selectedAssetsArray.count;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.selectedAssetsArray removeObjectAtIndex:indexPath.row];
    [self.delegate assetPicker:nil didChangeSelectionTo:self.selectedAssetsArray];
    [collectionView reloadData];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(kSelectedAssetCellSquareSize, kSelectedAssetCellSquareSize);
}

@end
