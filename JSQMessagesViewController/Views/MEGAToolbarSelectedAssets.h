
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

#import "MEGAToolbarAssetPicker.h"

@interface MEGAToolbarSelectedAssets : NSObject <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView
                   selectedAssetsArray:(NSMutableArray<PHAsset *> *)selectedAssetsArray
                              delegate:(id<MEGAToolbarAssetPickerDelegate>)delegate;

- (void)setSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray;

@end
