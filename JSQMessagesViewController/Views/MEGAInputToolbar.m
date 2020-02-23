
#import "MEGAInputToolbar.h"

#import "SVProgressHUD.h"

#import "DevicePermissionsHelper.h"
#import "NSDate+MNZCategory.h"
#import "NSFileManager+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIColor+MNZCategory.h"

static void * kMEGAInputToolbarKeyValueObservingContext = &kMEGAInputToolbarKeyValueObservingContext;

extern const CGFloat kCellSquareSize;
extern const CGFloat kCellInset;
extern const NSUInteger kCellRows;
const CGFloat kButtonBarHeight = 50.0f;
const CGFloat kTextContentViewHeight = 86.0f;
const CGFloat kSelectedAssetsViewHeight = 200.0f;
const CGFloat kTextViewHorizontalMargins = 34.0f;
const CGFloat kMinimunRecordDuration = 1.0f;
CGFloat kImagePickerViewHeight;

const CGFloat kRecordImageUpDownTime = 0.4f;
const CGFloat kRecordImageRotateTime = 0.1f;
const CGFloat kGarbageAnimationTime = 0.3f;
const CGFloat kGarbageBeginY = 100.0f;

const CGFloat kLineHeight = 18.0f;
const NSUInteger kMaxLinesWhenCollapsed = 5;
const CGFloat kOriginalTextViewHeight = 2.0f + kLineHeight;
const CGFloat kMaxTextViewHeight = kMaxLinesWhenCollapsed * kLineHeight;
const CGFloat kMaxToolbarHeight = kTextContentViewHeight - kOriginalTextViewHeight + kMaxTextViewHeight;

static NSString * const kMEGAUIKeyInputCarriageReturn = @"\r";

typedef NS_ENUM(NSUInteger, InputToolbarMode) {
    InputToolbarModeCollapsed,
    InputToolbarModeExpanded
};

@interface MEGAInputToolbar ()

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (nonatomic) MEGAToolbarAssetPicker *assetPicker;
@property (nonatomic) MEGAToolbarSelectedAssets *selectedAssets;
@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;

@property (nonatomic) InputToolbarState currentState;
@property (nonatomic) InputToolbarMode currentMode;
@property (nonatomic) CGPoint longPressInitialPoint;
@property (nonatomic) CGRect slideToCancelOriginalFrame;
@property (nonatomic) AVAudioRecorder *audioRecorder;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSDate *baseDate;
@property (nonatomic) CGFloat currentToolbarHeight;
@property (nonatomic) UINotificationFeedbackGenerator *hapticGenerator;
@property (nonatomic) CGPoint panGestureInitialPoint;
@property (nonatomic) CGFloat panGestureInitialToolbarHeight;

@end

@implementation MEGAInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
    self.jsq_isObserving = NO;
    
    kImagePickerViewHeight = kButtonBarHeight + (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
    _selectedAssetsArray = [NSMutableArray new];
    _hapticGenerator = UINotificationFeedbackGenerator.alloc.init;

    [self loadToolbarTextContentView];
}

- (void)layoutSubviews {
    // Scroll to bottom of the text view:
    if (self.contentView) {
        [self resizeToolbarIfNeeded];
        [self.contentView.textView scrollRangeToVisible:NSMakeRange([self.contentView.textView.text length], 0)];
    } else {
        [self.delegate messagesInputToolbar:self needsResizeToHeight:kImagePickerViewHeight];
    }
}

- (void)loadToolbarTextContentView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:@"MEGAToolbarTextContentView"
                                                                                         owner:nil
                                                                                       options:nil];
    MEGAToolbarContentView *textContentView = nibViews.firstObject;
    [self setupTextContentView:textContentView];
    _contentView = textContentView;
    [self.delegate messagesInputToolbar:self didLoadContentView:self.contentView];
}

- (void)loadToolbarImagePickerView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:@"MEGAToolbarImagePickerView"
                                                                                         owner:nil
                                                                                       options:nil];
    MEGAToolbarContentView *imagePickerView = nibViews.firstObject;
    [self setupImagePickerView:imagePickerView];
    _imagePickerView = imagePickerView;
}

- (void)setupTextContentView:(MEGAToolbarContentView *)textContentView {
    textContentView.frame = self.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, kTextContentViewHeight);
    [self addSubview:textContentView];
    [self removeTargetsFromView:textContentView];
    [self addTargetsToView:textContentView];
    [self.delegate messagesInputToolbar:self needsResizeToHeight:kTextContentViewHeight];
    
    [self updateToolbar];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidChangeNotification:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:textContentView.textView];
    
    // Observe remote changes of the text within the textView, useful when the user edits the content of a message:
    [textContentView.textView addObserver:self forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:nil];
    [self resizeToolbarIfNeeded];
}

- (void)setupImagePickerView:(MEGAToolbarContentView *)imagePickerView {
    imagePickerView.frame = self.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, kImagePickerViewHeight);
    if (self.selectedAssetsArray.count == 0) {
        imagePickerView.selectedAssetsCollectionView.frame = CGRectMake(0.0f, 1.0f, self.frame.size.width, 0.0f);
    } else {
        imagePickerView.selectedAssetsCollectionView.frame = CGRectMake(0.0f, 1.0f, self.frame.size.width, kSelectedAssetsViewHeight - kButtonBarHeight);
        imagePickerView.sendButton.enabled = YES;
    }
    UIImage *sendButton = [UIImage imageNamed:@"sendButton"];
    [imagePickerView.sendButton setImage:sendButton.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
    [self addSubview:imagePickerView];
    [self removeTargetsFromView:imagePickerView];
    [self addTargetsToView:imagePickerView];
    [self.delegate messagesInputToolbar:self needsResizeToHeight:kImagePickerViewHeight];

    self.assetPicker = [[MEGAToolbarAssetPicker alloc]
                        initWithCollectionView:imagePickerView.collectionView
                        selectedAssetsArray:self.selectedAssetsArray
                        delegate:self];
    imagePickerView.collectionView.dataSource = self.assetPicker;
    imagePickerView.collectionView.delegate = self.assetPicker;
    
    self.selectedAssets = [[MEGAToolbarSelectedAssets alloc]
                           initWithCollectionView:imagePickerView.selectedAssetsCollectionView
                           selectedAssetsArray:self.selectedAssetsArray
                           delegate:self];
    imagePickerView.selectedAssetsCollectionView.dataSource = self.selectedAssets;
    imagePickerView.selectedAssetsCollectionView.delegate = self.selectedAssets;
    [imagePickerView.selectedAssetsCollectionView reloadData];
}

- (void)dealloc {
    if (self.contentView) {
        [self removeTargetsFromView:self.contentView];
        [self.contentView.textView removeObserver:self forKeyPath:@"text"];
    } else {
        [self removeTargetsFromView:self.imagePickerView];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (NSArray<UIKeyCommand *> *)keyCommands {
    return @[[UIKeyCommand keyCommandWithInput:kMEGAUIKeyInputCarriageReturn modifierFlags:0 action:@selector(jsq_sendButtonPressed:)]];
}

- (void)jsq_sendButtonPressed:(UIButton *)sender {
    if (self.contentView) {
        switch (self.currentState) {
            case InputToolbarStateInitial:
                [self.delegate messagesInputToolbar:self didPressNotHeldRecordButton:sender];
                [self.hapticGenerator notificationOccurred:UINotificationFeedbackTypeError];
                break;
                
            case InputToolbarStateWriting:
                [self.delegate messagesInputToolbar:self didPressSendButton:sender];
                break;
                
            case InputToolbarStateRecordingUnlocked:
                break;
                
            case InputToolbarStateRecordingLocked:
                [self stopRecordingAudioToSend:YES];
                self.contentView.textView.text = @"";
                self.currentState = InputToolbarStateInitial;
                [self updateToolbar];
                break;
        }
    } else {
        [self.delegate messagesInputToolbar:self didPressSendButton:sender toAttachAssets:self.selectedAssetsArray];
        self.selectedAssetsArray = [NSMutableArray new];
        [self assetPicker:nil didChangeSelectionTo:self.selectedAssetsArray];
        [self.imagePickerView removeFromSuperview];
        [self loadToolbarTextContentView];
    }
}

- (void)mnz_accesoryButtonPressed:(UIButton *)sender {
    if (self.currentMode == InputToolbarModeExpanded) {
        [self mnz_expandOrCollapseButtonPressed];
    }
    
    switch (sender.tag) {
        case MEGAChatAccessoryButtonText:
            if (self.imagePickerView) {
                [self.imagePickerView removeFromSuperview];
                [self loadToolbarTextContentView];
                // Become first responder unanimated:
                [UIView animateWithDuration:0.0f
                                 animations:^{
                                     [self.contentView.textView becomeFirstResponder];
                                 }
                                 completion:nil];
                [self.delegate messagesInputToolbar:self didPressAccessoryButton:sender];
            }
            break;
            
        case MEGAChatAccessoryButtonImage:
            if (self.imagePickerView) {
                [UIView animateWithDuration:0.2f
                                 animations:^{
                                     self.imagePickerView.frame = CGRectMake(
                                                                             self.imagePickerView.frame.origin.x,
                                                                             self.imagePickerView.frame.origin.y + (kImagePickerViewHeight - kButtonBarHeight),
                                                                             self.imagePickerView.frame.size.width,
                                                                             self.imagePickerView.frame.size.height);
                                 }
                                 completion:^(BOOL finished){
                                     [self.imagePickerView removeFromSuperview];
                                     [self loadToolbarTextContentView];
                                 }];
            } else {
                if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
                    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (!self.imagePickerView) {
                                [self.contentView.textView removeObserver:self forKeyPath:@"text"];
                                [self.contentView removeFromSuperview];
                                [self loadToolbarImagePickerView];
                            }
                        });
                    }];
                } else {
                    if (!self.imagePickerView) {
                        BOOL keyboardWasPresent = [self.contentView.textView isFirstResponder];
                        [self.contentView.textView removeObserver:self forKeyPath:@"text"];
                        [self.contentView removeFromSuperview];
                        [self loadToolbarImagePickerView];
                        if (!keyboardWasPresent) {
                            self.imagePickerView.frame = CGRectMake(
                                                                    self.imagePickerView.frame.origin.x,
                                                                    self.imagePickerView.frame.origin.y + (kImagePickerViewHeight - kButtonBarHeight),
                                                                    self.imagePickerView.frame.size.width,
                                                                    self.imagePickerView.frame.size.height);
                            [UIView animateWithDuration:0.2f
                                             animations:^{
                                                 self.imagePickerView.frame = CGRectMake(
                                                                                         self.imagePickerView.frame.origin.x,
                                                                                         self.imagePickerView.frame.origin.y - (kImagePickerViewHeight - kButtonBarHeight),
                                                                                         self.imagePickerView.frame.size.width,
                                                                                         self.imagePickerView.frame.size.height);
                                             }
                                             completion:nil];
                        }
                    }
                }
            }
            [self.delegate messagesInputToolbar:self didPressAccessoryButton:sender];
            break;
            
        default:
            if (self.imagePickerView) {
                [self.imagePickerView removeFromSuperview];
                [self loadToolbarTextContentView];
            } else if ([self.contentView.textView isFirstResponder]) {
                [self.contentView.textView resignFirstResponder];
            }
            [self.delegate messagesInputToolbar:self didPressAccessoryButton:sender];
            break;
    }
}

- (void)mnz_joinButtonPressed:(UIButton *)sender {
    [self.delegate messagesInputToolbar:self didPressJoinButton:sender];
}

- (void)mnz_cancelRecording:(UIButton *)sender {
    [self setFixedAnchorPointForHeaderGarbageView];
    [self stopRecordingAudioToSend:NO];
    self.contentView.textView.text = @"";
    self.currentState = InputToolbarStateInitial;
    
    CGRect originalFrame = self.contentView.recordButton.frame;
    
    [UIView animateWithDuration:kRecordImageUpDownTime delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect frame = self.contentView.recordButton.frame;
        frame.origin.y -= (2.5 * self.contentView.recordButton.frame.size.height);
        self.contentView.recordButton.frame = frame;
    } completion:^(BOOL finished) {
        if (finished) {
            [self showGarbage];
        }
    }];
    
    [UIView animateWithDuration:kRecordImageRotateTime delay:0.3 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGAffineTransform transForm = CGAffineTransformMakeRotation(0.5 * M_PI);
        self.contentView.recordButton.transform = transForm;
    } completion:nil];
    
    [UIView animateWithDuration:kRecordImageUpDownTime delay:0.4 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.contentView.recordButton.frame = originalFrame;
        self.contentView.recordButton.alpha = 0.1f;
    } completion:^(BOOL finished) {
        self.contentView.recordButton.hidden = YES;
        [self dismissGarbage];
    }];
    
    [UIView animateWithDuration:kRecordImageRotateTime delay:0.4 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGAffineTransform transForm = CGAffineTransformMakeRotation(1 * M_PI);
        self.contentView.recordButton.transform = transForm;
    } completion:nil];
}

#pragma mark - Animations cancel voice clip

- (void)dismissGarbage {
    self.contentView.garbageView.alpha = 1.0f;
    [UIView animateWithDuration:kGarbageAnimationTime delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.contentView.headerGarbageView.transform = CGAffineTransformIdentity;
        CGRect frame = self.contentView.garbageView.frame;
        frame.origin.y = kGarbageBeginY;
        self.contentView.garbageView.frame = frame;
        self.contentView.garbageView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateToolbar];
            
            self.contentView.garbageView.hidden = YES;
            self.contentView.recordButton.transform = CGAffineTransformIdentity;
            self.contentView.recordButton.alpha = 1.0f;
            self.contentView.recordButton.hidden = NO;
        });
    }];
}

- (void)showGarbage {
    self.contentView.garbageView.hidden = NO;
    self.contentView.garbageView.alpha = 0.0f;
    
    [UIView animateWithDuration:kGarbageAnimationTime delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGAffineTransform transForm = CGAffineTransformMakeRotation(-1 * M_PI_2);
        self.contentView.headerGarbageView.transform = transForm;
        CGRect frame = self.contentView.garbageView.frame;
        frame.origin.y = self.contentView.recordingTimeLabel.frame.origin.y;
        self.contentView.garbageView.frame = frame;
        self.contentView.garbageView.alpha = 1.0f;
    } completion:nil];
}

- (void)setFixedAnchorPointForHeaderGarbageView {
    CGPoint anchorPoint = CGPointMake(0, 1);
    CGPoint newPoint = CGPointMake(self.contentView.headerGarbageView.bounds.size.width * anchorPoint.x, self.contentView.headerGarbageView.bounds.size.height * anchorPoint.y);
    CGPoint oldPoint = CGPointMake(self.contentView.headerGarbageView.bounds.size.width * self.contentView.headerGarbageView.layer.anchorPoint.x, self.contentView.headerGarbageView.bounds.size.height * self.contentView.headerGarbageView.layer.anchorPoint.y);
    
    newPoint = CGPointApplyAffineTransform(newPoint, self.contentView.headerGarbageView.transform);
    oldPoint = CGPointApplyAffineTransform(oldPoint, self.contentView.headerGarbageView.transform);
    
    CGPoint position = self.contentView.headerGarbageView.layer.position;
    
    position.x -= oldPoint.x;
    position.x += newPoint.x;
    
    position.y -= oldPoint.y;
    position.y += newPoint.y;
    
    self.contentView.headerGarbageView.layer.position = position;
    self.contentView.headerGarbageView.layer.anchorPoint = anchorPoint;
}

#pragma mark - Voice clips

- (BOOL)startRecordingAudio {

    if ([self.delegate messagesInputToolbarCanRecordVoiceClip:self]) {
        NSError *error;

        if (![AVAudioSession.sharedInstance setMode:AVAudioSessionModeDefault error:&error]) {
            MEGALogError(@"[Voice clips] Error setting default mode: %@", error);
        }
        
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            MEGALogError(@"[Voice clips] Error activating audio session: %@", error);
            return [self handleAVAudioSessionError:error];
        }
        
        AudioFormatID audioFormat = kAudioFormatMPEG4AAC;
        NSString *extension = @"m4a";
        
        if (![NSFileManager.defaultManager fileExistsAtPath:NSTemporaryDirectory()]) {
            if (![NSFileManager.defaultManager createDirectoryAtPath:NSTemporaryDirectory() withIntermediateDirectories:YES attributes:nil error:&error]) {
                MEGALogError(@"[Voice clips] Error creating temporary directory: %@", error);
                return NO;
            }
        }
        
        NSURL *destinationURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [[NSDate date] mnz_formattedDefaultNameForMedia], extension]]];
        
        NSDictionary *recordSettings = @{ AVFormatIDKey: @(audioFormat),
                                            AVSampleRateKey: @(16000),
                                            AVNumberOfChannelsKey: @(1),
                                            AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
                                            };
        self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:destinationURL settings:recordSettings error:&error];
        if (!self.audioRecorder) {
            MEGALogError(@"[Voice clips] Error instantiating audio recorder: %@", error);
            return NO;
        }
        self.audioRecorder.meteringEnabled = YES;
        
        self.timer = [NSTimer timerWithTimeInterval:0.1f target:self selector:@selector(updateRecordingTimeLabel) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        self.baseDate = [NSDate date];
        
        return [self.audioRecorder record];
    } else {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"It is not possible to record voice messages while there is a call in progress", @"Message shown when there is an ongoing call and the user tries to record a voice message")];
        return NO;
    }
}

- (void)stopRecordingAudioToSend:(BOOL)send {
    [self.audioRecorder stop];
    [self.timer invalidate];
    NSURL *clipURL = self.audioRecorder.url;
    self.audioRecorder = nil;
    
    NSError *error;
    if (![AVAudioSession.sharedInstance setMode:AVAudioSessionModeVoiceChat error:&error]) {
        MEGALogError(@"[Voice clips] Error setting voice chat mode: %@", error);
    }
    
    if (![[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
        MEGALogError(@"[Voice clips] Error deactivating audio session: %@", error);
    }
    
    AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:clipURL error:nil];
    MEGALogDebug(@"[Voice clips] Stop recording: send %d, duration - %f", send, audioPlayer.duration);
    if (send && audioPlayer.duration >= kMinimunRecordDuration) {
        [self.delegate messagesInputToolbar:self didRecordVoiceClipAtPath:clipURL.path];
        [self.hapticGenerator notificationOccurred:UINotificationFeedbackTypeSuccess];
    } else {
        [NSFileManager.defaultManager mnz_removeItemAtPath:clipURL.path];
        [self.hapticGenerator notificationOccurred:UINotificationFeedbackTypeError];
    }
}

- (void)updateRecordingTimeLabel {
    NSTimeInterval interval = ([NSDate date].timeIntervalSince1970 - self.baseDate.timeIntervalSince1970);
    NSString *time = [NSString mnz_stringFromTimeInterval:interval];
    self.contentView.recordingTimeLabel.text = time;
    self.recordView.timeLabel.text = time;
    [self.audioRecorder updateMeters];
    double lowPassResults = pow(10, (0.05 * [self.audioRecorder peakPowerForChannel:0]));

    self.recordView.currentVolume = lowPassResults;
}

#pragma mark - Toolbar state

- (void)updateToolbar {
    switch (self.currentState) {
        case InputToolbarStateInitial:
            [self.contentView.sendButton setImage:[UIImage imageNamed:@"sendVoiceClipInactive"] forState:UIControlStateNormal];
            [self.contentView.slideToCancelButton setTitle:AMLocalizedString(@"< Slide to cancel", @"Text shown in the chat toolbar while the user is recording a voice clip. The < character should be > in RTL languages.") forState:UIControlStateNormal];
            [self.contentView.slideToCancelButton setTitleColor:UIColor.mnz_gray666666 forState:UIControlStateNormal];
            self.contentView.recordingTimeLabel.text = @"00:00";
            self.contentView.accessoryCameraButton.hidden = self.contentView.accessoryImageButton.hidden = self.contentView.accessoryUploadButton.hidden = self.contentView.textView.hidden = NO;
            self.contentView.recordingContainerView.hidden = self.contentView.slideToCancelButton.hidden = self.contentView.lockView.hidden = YES;
            self.contentView.slideToCancelButton.alpha = 1.0;
            
            break;
            
        case InputToolbarStateWriting: {
            UIImage *sendButton = [UIImage imageNamed:@"sendButton"];
            [self.contentView.sendButton setImage:sendButton.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
            self.contentView.sendButton.enabled = self.contentView.textView.hasText;
            self.contentView.recordingContainerView.hidden = self.contentView.slideToCancelButton.hidden = self.contentView.lockView.hidden = YES;
            
            break;
        }
            
        case InputToolbarStateRecordingUnlocked:
            [self.contentView.sendButton setImage:[UIImage imageNamed:@"sendVoiceClipActive"] forState:UIControlStateNormal];
            self.contentView.accessoryCameraButton.hidden = self.contentView.accessoryImageButton.hidden = self.contentView.accessoryUploadButton.hidden = self.contentView.textView.hidden = YES;
            self.contentView.recordingContainerView.hidden = self.contentView.slideToCancelButton.hidden = self.contentView.lockView.hidden = NO;
            
            break;
            
        case InputToolbarStateRecordingLocked: {
            UIImage *sendButton = [UIImage imageNamed:@"sendButton"];
            [self.contentView.sendButton setImage:sendButton.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
            [self.contentView.slideToCancelButton setTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") forState:UIControlStateNormal];
            [self.contentView.slideToCancelButton setTitleColor:UIColor.mnz_redMain forState:UIControlStateNormal];
            self.contentView.lockView.hidden = YES;
            
            break;
        }
    }
    
    [self.delegate messagesInputToolbar:self didChangeToState:self.currentState];
}

- (void)mnz_setJoinViewHidden:(BOOL)hidden {
    if (!hidden && !self.contentView) {
        self.selectedAssetsArray = [NSMutableArray new];
        [self assetPicker:nil didChangeSelectionTo:self.selectedAssetsArray];
        [self.imagePickerView removeFromSuperview];
        [self loadToolbarTextContentView];
    }
    self.contentView.opaqueContentView.hidden = !hidden;
    self.contentView.joinView.hidden = hidden;
}

- (void)mnz_setTypingIndicatorAttributedText:(NSAttributedString *)attributedText {
    if (!self.contentView) {
        return;
    }
    
    if (attributedText) {
        self.contentView.typingIndicatorLabel.attributedText = attributedText;
        self.contentView.typingIndicatorView.hidden = NO;
    } else {
        self.contentView.typingIndicatorView.hidden = YES;
    }
    [self resizeToolbarIfNeeded];
}

- (void)mnz_lockRecordingIfNeeded {
    if (self.currentState != InputToolbarStateRecordingUnlocked) {
        return;
    }
    
    self.contentView.slideToCancelButton.frame = self.slideToCancelOriginalFrame;
    self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentState = InputToolbarStateRecordingLocked;
    [self updateToolbar];
}

- (void)mnz_expandOrCollapseButtonPressed {
    if (self.currentMode == InputToolbarModeCollapsed) {
        if (self.contentView.textView.isFirstResponder) {
            self.currentMode = InputToolbarModeExpanded;
            UIImage *collapseImage = [UIImage imageNamed:@"collapse"];
            [self.contentView.expandOrCollapseButton setImage:collapseImage.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
            self.contentView.draggableViewHeightConstraint.constant = 45.0f;
            self.contentView.opaqueContentView.layer.cornerRadius = 13.0f;
            self.contentView.shadowContentView.hidden = NO;
        } else {
            [self.contentView.textView becomeFirstResponder];
        }
    } else {
        self.currentMode = InputToolbarModeCollapsed;
        UIImage *expandImage = [UIImage imageNamed:@"expand"];
        [self.contentView.expandOrCollapseButton setImage:expandImage.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
        self.contentView.draggableViewHeightConstraint.constant = 0.0f;
        self.contentView.opaqueContentView.layer.cornerRadius = 0.0f;
        self.contentView.shadowContentView.hidden = YES;
    }
    
    [self resizeToolbarIfNeeded];
}

#pragma mark - MEGAToolbarAssetPickerDelegate

- (void)assetPicker:(MEGAToolbarAssetPicker *)assetPicker didChangeSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray {
    self.imagePickerView.sendButton.enabled = selectedAssetsArray.count > 0;
    self.selectedAssetsArray = selectedAssetsArray;
    [self.assetPicker setSelectionTo:self.selectedAssetsArray];
    [self.selectedAssets setSelectionTo:self.selectedAssetsArray];
    if (selectedAssetsArray.count == 0) {
        kImagePickerViewHeight = kButtonBarHeight + (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
        self.imagePickerView.selectedAssetsCollectionView.frame = CGRectMake(0.0f, 1.0f, self.frame.size.width, 0.0f);
    } else {
        kImagePickerViewHeight = kSelectedAssetsViewHeight + (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
        self.imagePickerView.selectedAssetsCollectionView.frame = CGRectMake(0.0f, 1.0f, self.frame.size.width, kSelectedAssetsViewHeight - kButtonBarHeight);
    }
    
    if (self.imagePickerView) {
        self.imagePickerView.frame = self.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, kImagePickerViewHeight);
        [self.delegate messagesInputToolbar:self needsResizeToHeight:kImagePickerViewHeight];
    }
}

- (void)requestAssetFailedWithError:(NSError *)error {
    [self.delegate messagesInputToolbar:self assetLoadFailed:error];
}

#pragma mark - Notifications

- (void)textViewTextDidChangeNotification:(NSNotification *)notification {
    if (self.currentState == InputToolbarStateRecordingUnlocked || self.currentState == InputToolbarStateRecordingLocked) {
        return;
    }
    
    self.currentState = self.contentView.textView.text.length ? InputToolbarStateWriting : InputToolbarStateInitial;
    [self updateToolbar];
    [self resizeToolbarIfNeeded];
}

- (void)resizeToolbarIfNeeded {
    CGFloat newToolbarHeight = [self heightToFitInWidth:self.contentView.textView.frame.size.width];
    self.contentView.contentViewHeightConstraint.constant = newToolbarHeight;
    [self.contentView layoutIfNeeded];
    [self.delegate messagesInputToolbar:self needsResizeToHeight:newToolbarHeight + (self.contentView.typingIndicatorView.hidden ? 0 : self.contentView.typingIndicatorView.frame.size.height)];
}

- (CGFloat)heightToFitInWidth:(CGFloat)width {
    if (self.currentMode == InputToolbarModeCollapsed) {
        CGSize sizeThatFits = [self.contentView.textView sizeThatFits:CGSizeMake(width, self.contentView.textView.frame.size.height)];
        CGFloat textViewHeightNeeded = sizeThatFits.height;
        self.contentView.expandOrCollapseButton.hidden = textViewHeightNeeded / kLineHeight < kMaxLinesWhenCollapsed;
        textViewHeightNeeded = textViewHeightNeeded > kMaxTextViewHeight ? kMaxTextViewHeight : textViewHeightNeeded;
        CGFloat newToolbarHeight = kTextContentViewHeight - kOriginalTextViewHeight + textViewHeightNeeded;
        return newToolbarHeight;
    } else {
        CGFloat topPadding = 0.0f;
        if (@available(iOS 11.0, *)) {
            topPadding = UIApplication.sharedApplication.keyWindow.safeAreaInsets.top;
        }
        return self.superview.superview.frame.size.height - self.superview.frame.size.height - topPadding + self.contentView.contentViewHeightConstraint.constant;
    }
}

#pragma mark - Targets

- (void)addTargetsToView:(MEGAToolbarContentView *)view {
    [view.sendButton addTarget:self
                        action:@selector(jsq_sendButtonPressed:)
              forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryCameraButton addTarget:self
                                   action:@selector(mnz_accesoryButtonPressed:)
                         forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryImageButton addTarget:self
                                  action:@selector(mnz_accesoryButtonPressed:)
                        forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryUploadButton addTarget:self
                                   action:@selector(mnz_accesoryButtonPressed:)
                         forControlEvents:UIControlEventTouchUpInside];
    
    [view.joinButton addTarget:self
                        action:@selector(mnz_joinButtonPressed:)
              forControlEvents:UIControlEventTouchUpInside];
    
    [view.slideToCancelButton addTarget:self
                                 action:@selector(mnz_cancelRecording:)
                       forControlEvents:UIControlEventTouchUpInside];
    
    [view.expandOrCollapseButton addTarget:self
                                    action:@selector(mnz_expandOrCollapseButtonPressed)
                          forControlEvents:UIControlEventTouchUpInside];
    
    [view.sendButton addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    
    [view.draggableView addGestureRecognizer:[UIPanGestureRecognizer.alloc initWithTarget:self action:@selector(panGesture:)]];
}

- (void)removeTargetsFromView:(MEGAToolbarContentView *)view {
    [view.sendButton removeTarget:self
                           action:NULL
                 forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryCameraButton removeTarget:self
                                      action:NULL
                            forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryImageButton removeTarget:self
                                     action:NULL
                           forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryUploadButton removeTarget:self
                                      action:NULL
                            forControlEvents:UIControlEventTouchUpInside];
    
    [view.joinButton removeTarget:self
                           action:NULL
                 forControlEvents:UIControlEventTouchUpInside];

    [view.slideToCancelButton removeTarget:self
                                    action:NULL
                          forControlEvents:UIControlEventTouchUpInside];
    
    [view.expandOrCollapseButton removeTarget:self
                                       action:NULL
                             forControlEvents:UIControlEventTouchUpInside];
    
    for (UIGestureRecognizer *gestureRecognizer in view.sendButton.gestureRecognizers) {
        [view.sendButton removeGestureRecognizer:gestureRecognizer];
    }
    
    for (UIGestureRecognizer *gestureRecognizer in view.draggableView.gestureRecognizers) {
        [view.draggableView removeGestureRecognizer:gestureRecognizer];
    }
}

# pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self textViewTextDidChangeNotification:nil];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    switch (longPressGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.currentState != InputToolbarStateInitial) {
                return;
            }
            
            if ([DevicePermissionsHelper shouldAskForAudioPermissions]) {
                [DevicePermissionsHelper audioPermissionModal:YES forIncomingCall:NO withCompletionHandler:nil];
            } else {
                [DevicePermissionsHelper audioPermissionModal:YES forIncomingCall:NO withCompletionHandler:^(BOOL granted) {
                    if (granted) {
                        self.longPressInitialPoint = [longPressGestureRecognizer locationInView:self];
                        self.slideToCancelOriginalFrame = self.contentView.slideToCancelButton.frame;
                        self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = YES;
                        
                        if ([self startRecordingAudio]) {
                            self.currentState = InputToolbarStateRecordingUnlocked;
                            [self updateToolbar];
                        }
                    } else {
                        [DevicePermissionsHelper alertAudioPermissionForIncomingCall:NO];
                    }
                }];
            }
            
            break;
            
        }
            
        case UIGestureRecognizerStateChanged: {
            if (self.currentState != InputToolbarStateRecordingUnlocked) {
                return;
            }
            
            CGFloat xIncrement = ABS([longPressGestureRecognizer locationInView:self].x - self.longPressInitialPoint.x);
            CGFloat yIncrement = [longPressGestureRecognizer locationInView:self].y - self.longPressInitialPoint.y;
            if (yIncrement < -70.0f) {
                self.contentView.slideToCancelButton.frame = self.slideToCancelOriginalFrame;
                self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
                self.currentState = InputToolbarStateRecordingLocked;
                [self updateToolbar];
            } else if (xIncrement > 100.0f) {
                self.contentView.slideToCancelButton.frame = self.slideToCancelOriginalFrame;
                self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
                [self mnz_cancelRecording:self.contentView.slideToCancelButton];
            } else if (xIncrement < 100.0f && xIncrement > 0.0f) {
                CGRect frame = self.slideToCancelOriginalFrame;
                BOOL isRTLLanguage = UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
                frame.origin.x = isRTLLanguage ? frame.origin.x + xIncrement : frame.origin.x - xIncrement;
                self.contentView.slideToCancelButton.frame = frame;
                self.contentView.slideToCancelButton.alpha = 1.0 - xIncrement / 100;
                if (xIncrement > 50.0f) {
                    [self.contentView.slideToCancelButton setTitleColor:UIColor.mnz_redMain forState:UIControlStateNormal];
                } else {
                    [self.contentView.slideToCancelButton setTitleColor:UIColor.mnz_gray666666 forState:UIControlStateNormal];
                }
            }
            
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            if (self.currentState != InputToolbarStateRecordingUnlocked) {
                return;
            }
            
            [self stopRecordingAudioToSend:YES];
            self.contentView.slideToCancelButton.frame = self.slideToCancelOriginalFrame;
            self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = NO;
            self.contentView.textView.text = @"";
            self.currentState = InputToolbarStateInitial;
            [self updateToolbar];
            
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - UIPanGestureRecognizer

- (void)panGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    if (self.currentMode == InputToolbarModeCollapsed) {
        return;
    }
    
    CGPoint touchPoint = [panGestureRecognizer translationInView:self.contentView];
    CGFloat verticalIncrement = touchPoint.y - self.panGestureInitialPoint.y;
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.panGestureInitialPoint = touchPoint;
            self.panGestureInitialToolbarHeight = self.contentView.contentViewHeightConstraint.constant;
            break;
            
        case UIGestureRecognizerStateChanged:
            if (verticalIncrement > self.panGestureInitialToolbarHeight - kMaxToolbarHeight) {
                return;
            }
            if (verticalIncrement > 0) {
                self.contentView.contentViewHeightConstraint.constant = self.panGestureInitialToolbarHeight - verticalIncrement;
            }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (verticalIncrement > 50.0f) {
                [self mnz_expandOrCollapseButtonPressed];
            } else {
                [UIView animateWithDuration:0.3 animations:^{
                    self.contentView.contentViewHeightConstraint.constant = self.panGestureInitialToolbarHeight;
                    [self.contentView layoutIfNeeded];
                }];
            }
            self.panGestureInitialPoint = CGPointZero;
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Private methods.

- (BOOL)handleAVAudioSessionError:(NSError *)error {
    AVAudioSessionErrorCode errorCode = error.code;
    NSString *errorMessage;
    switch (errorCode) {
        case AVAudioSessionErrorCodeInsufficientPriority:
            errorMessage = AMLocalizedString(@"It is not possible to record voice messages while there is a call in progress", @"Message shown when there is an ongoing call and the user tries to record a voice message");
            break;
            
        default:
            errorMessage = error.localizedDescription;
            break;
    }
    [SVProgressHUD showErrorWithStatus:errorMessage];
    return NO;
}

@end
