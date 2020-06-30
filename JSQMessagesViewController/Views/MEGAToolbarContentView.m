
#import "MEGAToolbarContentView.h"

#import "MEGA-Swift.h"

@implementation MEGAToolbarContentView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.lockView.layer.borderColor = [UIColor.blackColor colorWithAlphaComponent:0.1].CGColor;
    self.lockView.layer.borderWidth = 1.0f;
    
    [self updateAppearance];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateAppearance];
        }
    }
}

#pragma mark - Private

- (void)updateAppearance {
    self.topSeparatorView.backgroundColor = [UIColor mnz_separatorForTraitCollection:self.traitCollection];
    
    self.backgroundColor = self.opaqueContentView.backgroundColor = [UIColor mnz_secondaryBackgroundForTraitCollection:self.traitCollection];
    
    self.selectedAssetsCollectionView.backgroundColor = self.collectionView.backgroundColor = UIColor.mnz_background;
    
    self.lockView.backgroundColor = UIColor.mnz_background;
    
    self.joinView.backgroundColor = UIColor.mnz_background;
    [self.joinButton mnz_setupPrimary:self.traitCollection];
}

@end
