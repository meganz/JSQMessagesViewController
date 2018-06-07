
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@class MEGAToolbarAssetPicker;

@protocol MEGAToolbarAssetPickerDelegate

@required

- (void)assetPicker:(MEGAToolbarAssetPicker *)assetPicker didChangeSelectionTo:(NSArray<PHAsset *> *)assetsArray;
- (void)requestAssetFailedWithError:(NSError *)error;

@end

@interface MEGAToolbarAssetPicker : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                   selectedAssetsArray:(NSMutableArray<PHAsset *> *)selectedAssetsArray
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate;

- (void)setSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray;

@end
