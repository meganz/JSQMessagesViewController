
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@class MEGAToolbarAssetPicker;

@protocol MEGAToolbarAssetPickerDelegate

@required

- (void)assetPicker:(MEGAToolbarAssetPicker *)assetPicker didChangeSelectionTo:(NSArray<PHAsset *> *)assetsArray;

@end

@interface MEGAToolbarAssetPicker : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate;
- (void)resetSelection;

@end
