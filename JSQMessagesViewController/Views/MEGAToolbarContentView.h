
#import <UIKit/UIKit.h>

#import "JSQMessagesComposerTextView.h"

/**
 *  A `MEGAToolbarContentView` represents the content displayed in a `MEGAInputToolbar`.
 *  These subviews consist of a text view and some buttons. One button is used as
 *  the send button, and the others as accessory buttons. The text view is used for composing messages.
 */
@interface MEGAToolbarContentView : UIView

/**
 *  The text view in which the user composes a message.
 */
@property (weak, nonatomic) IBOutlet JSQMessagesComposerTextView *textView;

/**
 *  The button to send messages, displayed on the right of the toolbar content view.
 */
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@end
