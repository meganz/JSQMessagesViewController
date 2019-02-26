
#import "MEGAToolbarContentView.h"

@implementation MEGAToolbarContentView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.lockView.layer.borderColor = UIColor.mnz_black000000_01.CGColor;
    self.lockView.layer.borderWidth = 1.0f;
}

@end
