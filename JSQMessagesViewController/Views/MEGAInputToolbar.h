
#import <UIKit/UIKit.h>

#import "MEGAToolbarContentView.h"

@class MEGAInputToolbar;

/**
 *  The `MEGAInputToolbarDelegate` protocol defines methods for interacting with
 *  a `MEGAInputToolbar` object.
 */
@protocol MEGAInputToolbarDelegate <UIToolbarDelegate>

@required

/**
 *  Tells the delegate that the toolbar's `sendButton` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
          didPressSendButton:(UIButton *_Nonnull)sender;

/**
 *  Tells the delegate that one toolbar's `accessoryButton` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
     didPressAccessoryButton:(UIButton *_Nonnull)sender;

@optional

- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
         needsResizeToHeight:(CGFloat)newToolbarHeight;

@end

/**
 *  An instance of `MEGAInputToolbar` defines the input toolbar for
 *  composing a new message. It is displayed above and follow the movement of the system keyboard.
 */
@interface MEGAInputToolbar : UIToolbar

/**
 *  The object that acts as the delegate of the toolbar.
 */
@property (weak, nonatomic, nullable) id<MEGAInputToolbarDelegate> delegate;

/**
 *  Returns the content view of the toolbar. This view contains all subviews of the toolbar.
 */
@property (weak, nonatomic, readonly, nullable) MEGAToolbarContentView *contentView;

/**
 *  Loads the content view for the toolbar.
 *
 *  @discussion Override this method to provide a custom content view for the toolbar.
 *
 *  @return An initialized `MEGAToolbarContentView`.
 */
- (MEGAToolbarContentView *_Nonnull)loadToolbarContentView;

@end
