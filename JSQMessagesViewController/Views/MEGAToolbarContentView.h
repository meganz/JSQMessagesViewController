
#import <UIKit/UIKit.h>

#import "JSQMessagesComposerTextView.h"

typedef NS_ENUM(NSUInteger, MEGAChatAccessoryButton) {
    MEGAChatAccessoryButtonText = 10,
    MEGAChatAccessoryButtonCamera,
    MEGAChatAccessoryButtonImage,
    MEGAChatAccessoryButtonUpload
};

/**
 *  A `MEGAToolbarContentView` represents the content displayed in a `MEGAInputToolbar`.
 *  These subviews consist of a text view and some buttons. One button is used as
 *  the send button, and the others as accessory buttons. The text view is used for composing messages.
 */
@interface MEGAToolbarContentView : UIView

@property (weak, nonatomic) IBOutlet UIVisualEffectView *typingIndicatorView;
@property (weak, nonatomic) IBOutlet UILabel *typingIndicatorLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *joinView;
@property (weak, nonatomic) IBOutlet UIButton *joinButton;

/**
 *  The text view in which the user composes a message.
 */
@property (weak, nonatomic) IBOutlet JSQMessagesComposerTextView *textView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *selectedAssetsCollectionView;
@property (weak, nonatomic) IBOutlet UIView *opaqueContentView;
@property (weak, nonatomic) IBOutlet UIView *shadowContentView;

/**
 *  The button to send messages, displayed on the right of the toolbar content view.
 */
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (weak, nonatomic) IBOutlet UIButton *accessoryCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *accessoryImageButton;
@property (weak, nonatomic) IBOutlet UIButton *accessoryUploadButton;

@property (weak, nonatomic) IBOutlet UILabel *recordingTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *slideToCancelButton;
@property (weak, nonatomic) IBOutlet UIView *lockView;
@property (weak, nonatomic) IBOutlet UIView *recordingContainerView;
@property (weak, nonatomic) IBOutlet UIImageView *bodyGarbageView;
@property (weak, nonatomic) IBOutlet UIImageView *headerGarbageView;
@property (weak, nonatomic) IBOutlet UIView *garbageView;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *expandOrCollapseButton;
@property (weak, nonatomic) IBOutlet UIView *draggableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *draggableViewHeightConstraint;

@end
