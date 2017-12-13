
#import "MEGAToolbarContentView.h"

@implementation MEGAToolbarContentView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [_sendButton setTitle:AMLocalizedString(@"send", @"Label for any 'Send' button, link, text, title, etc. - (String as short as possible).") forState:UIControlStateNormal];
}

@end
