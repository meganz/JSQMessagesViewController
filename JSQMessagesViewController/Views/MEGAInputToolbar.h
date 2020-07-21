
#import <UIKit/UIKit.h>

#import "JoinViewState.h"
#import "MEGAToolbarAssetPicker.h"
#import "MEGAToolbarContentView.h"
#import "MEGAToolbarSelectedAssets.h"

@class MEGAInputToolbar, MEGARecordView;

typedef NS_ENUM(NSUInteger, InputToolbarState) {
    InputToolbarStateInitial,
    InputToolbarStateWriting,
    InputToolbarStateRecordingUnlocked,
    InputToolbarStateRecordingLocked
};

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
 *  Tells the delegate that the toolbar's `sendButton` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
          didPressSendButton:(UIButton *_Nonnull)sender
              toAttachAssets:(NSArray<PHAsset *>*_Nullable)assets;

/**
 *  Tells the delegate that the toolbar's `sendButton` has been tapped (not held)
 *  to record a voice clip. An informative tooltip should be shown.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
 didPressNotHeldRecordButton:(UIButton *_Nullable)sender;

/**
 *  Tells the delegate that there is a voice clip ready to be sent.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param path    The path of the voice clip.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
    didRecordVoiceClipAtPath:(NSString *_Nonnull)voiceClipPath;

/**
 *  Tells the delegate that one toolbar's `accessoryButton` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
     didPressAccessoryButton:(UIButton *_Nonnull)sender;

/**
 *  Tells the delegate that the toolbar's `joinButton` has been pressed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param sender  The button that received the touch event.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
          didPressJoinButton:(UIButton *_Nonnull)sender;

/**
 *  Tells the delegate that Photos framework failed fetching asset.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param error The error that received from Photos framework.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
             assetLoadFailed:(NSError *_Nonnull)error;

/**
 *  Tells the delegate that the state of the toolbar has changed.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 *  @param state The new state.
 */
- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
            didChangeToState:(InputToolbarState)state;

/**
 *  Asks the delegate if there is some reason to forbid recording audio.
 *
 *  @param toolbar The object representing the toolbar sending this information.
 */
- (BOOL)messagesInputToolbarCanRecordVoiceClip:(MEGAInputToolbar *_Nonnull)toolbar;

@optional

- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
         needsResizeToHeight:(CGFloat)newToolbarHeight;

- (void)messagesInputToolbar:(MEGAInputToolbar *_Nonnull)toolbar
          didLoadContentView:(MEGAToolbarContentView *_Nonnull)toolbarContentView;

@end

/**
 *  An instance of `MEGAInputToolbar` defines the input toolbar for
 *  composing a new message. It is displayed above and follow the movement of the system keyboard.
 */
@interface MEGAInputToolbar : UIToolbar <MEGAToolbarAssetPickerDelegate>

@property (weak, nonatomic, nullable) MEGARecordView *recordView;
/**
 *  The object that acts as the delegate of the toolbar.
 */
@property (weak, nonatomic, nullable) id<MEGAInputToolbarDelegate> delegate;

/**
 *  Returns the content view of the toolbar. This view contains all subviews of the toolbar.
 */
@property (weak, nonatomic, readonly, nullable) MEGAToolbarContentView *contentView;

/**
 *  Returns the image picker view of the toolbar. This view contains all subviews of the toolbar.
 */
@property (weak, nonatomic, readonly, nullable) MEGAToolbarContentView *imagePickerView;

- (void)mnz_accesoryButtonPressed:(UIButton *_Nonnull)sender;
- (void)mnz_setJoinViewState:(JoinViewState)newState;
- (void)mnz_setTypingIndicatorAttributedText:(NSAttributedString *_Nullable)attributedText;
- (void)mnz_lockRecordingIfNeeded;

@end
