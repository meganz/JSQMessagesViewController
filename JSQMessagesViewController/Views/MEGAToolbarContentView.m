
#import "MEGAToolbarContentView.h"

@implementation MEGAToolbarContentView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.lockView.layer.borderColor = UIColor.mnz_black000000_01.CGColor;
    self.lockView.layer.borderWidth = 1.0f;
    
    self.tapAndHoldLabel.text = AMLocalizedString(@"Tap and hold", @"First part of the string 'Tap and hold <icon> to record, release to send'. There is a microphone icon between the two parts of the string.");
    self.releaseToSendLabel.text = AMLocalizedString(@"to record, release to send", @"Second part of the string 'Tap and hold <icon> to record, release to send'. There is a microphone icon between the two parts of the string.");
}

@end
