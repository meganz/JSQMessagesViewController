
#import "MEGAInputToolbar.h"

#import "NSDate+MNZCategory.h"
#import "NSString+MNZCategory.h"
#import "UIColor+MNZCategory.h"

static void * kMEGAInputToolbarKeyValueObservingContext = &kMEGAInputToolbarKeyValueObservingContext;

extern const CGFloat kCellSquareSize;
extern const CGFloat kCellInset;
extern const NSUInteger kCellRows;
const CGFloat kButtonBarHeight = 50.0f;
const CGFloat kTextContentViewHeight = 80.0f;
const CGFloat kSelectedAssetsViewHeight = 200.0f;
const CGFloat kTextViewHorizontalMargins = 34.0f;
CGFloat kImagePickerViewHeight;

static NSString * const kMEGAUIKeyInputCarriageReturn = @"\r";


@interface MEGAInputToolbar ()

typedef NS_ENUM(NSUInteger, InputToolbarState) {
    InputToolbarStateInitial,
    InputToolbarStateWriting,
    InputToolbarStateRecordingUnlocked,
    InputToolbarStateRecordingLocked
};

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (nonatomic) MEGAToolbarAssetPicker *assetPicker;
@property (nonatomic) MEGAToolbarSelectedAssets *selectedAssets;
@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;

@property (nonatomic) InputToolbarState currentState;
@property (nonatomic) CGPoint longPressInitialPoint;
@property (nonatomic) CGRect slideToCancelOriginalFrame;
@property (nonatomic) AVAudioRecorder *audioRecorder;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) NSDate *baseDate;

@end

@implementation MEGAInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
    self.jsq_isObserving = NO;
    
    kImagePickerViewHeight = kButtonBarHeight + (kCellRows+1)*kCellInset + kCellRows*kCellSquareSize;
    _selectedAssetsArray = [NSMutableArray new];
    
    [self loadToolbarTextContentView];
}

- (void)layoutSubviews {
    if (self.frame.size.width > [UIScreen mainScreen].bounds.size.width) {
        if (self.contentView) {
            CGFloat newTextViewWidth = [UIScreen mainScreen].bounds.size.width-kTextViewHorizontalMargins;
            self.contentView.frame = self.frame = CGRectMake(0.0f,
                                                             0.0f,
                                                             [UIScreen mainScreen].bounds.size.width,
                                                             [self heightToFitInWidth:newTextViewWidth]);
            self.contentView.textView.frame = CGRectMake(self.contentView.textView.frame.origin.x,
                                                         self.contentView.textView.frame.origin.y,
                                                         newTextViewWidth,
                                                         self.contentView.textView.frame.size.height);
        } else {
            self.imagePickerView.frame = self.frame = CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.width, kImagePickerViewHeight);
        }
    }
    // Scroll to bottom of the text view:
    if (self.contentView) {
        [self.contentView.textView scrollRangeToVisible:NSMakeRange([self.contentView.textView.text length], 0)];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (@available(iOS 11.0, *)) {
        if (self.window.safeAreaLayoutGuide != nil) {
            [[self bottomAnchor] constraintLessThanOrEqualToSystemSpacingBelowAnchor:self.window.safeAreaLayoutGuide.bottomAnchor multiplier:1.0].active = YES;
        }
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
        imagePickerView.sendButton.backgroundColor = [UIColor mnz_green00BFA5];
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
                break;
                
            case InputToolbarStateWriting:
                [self.delegate messagesInputToolbar:self didPressSendButton:sender];
                break;
                
            case InputToolbarStateRecordingUnlocked:
                break;
                
            case InputToolbarStateRecordingLocked:
                [self stopRecordingAudioToSend:YES];
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
    [self stopRecordingAudioToSend:NO];
    self.currentState = InputToolbarStateInitial;
    [self updateToolbar];
}

#pragma mark - Voice clips

- (BOOL)startRecordingAudio {
    NSError *error;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error]) {
        MEGALogError(@"[Voice clips] Error setting the audio category: %@", error);
        return NO;
    }
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        MEGALogError(@"[Voice clips] Error activating audio session: %@", error);
        return NO;
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
    NSDictionary *recordSettings = @{ AVNumberOfChannelsKey: @(1),
                                      AVFormatIDKey: @(audioFormat),
                                      AVSampleRateKey: @(16000),
                                      AVLinearPCMBitDepthKey: @(8),
                                      AVEncoderAudioQualityKey: @(AVAudioQualityMin),
                                      AVEncoderBitRateKey: @(8000),
                                      AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Variable,
                                      AVEncoderBitDepthHintKey: @(8),
                                      AVSampleRateConverterAudioQualityKey: @(AVAudioQualityMin),
                                      AVEncoderAudioQualityForVBRKey: @(AVAudioQualityMin)
                                      };
    
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:destinationURL settings:recordSettings error:&error];
    if (!self.audioRecorder) {
        MEGALogError(@"[Voice clips] Error instantiating audio recorder: %@", error);
        return NO;
    }
    
    self.timer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(updateRecordingTimeLabel) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    self.baseDate = [NSDate date];
    
    return [self.audioRecorder record];
}

- (void)stopRecordingAudioToSend:(BOOL)send {
    [self.audioRecorder stop];
    [self.timer invalidate];
    NSURL *clipURL = self.audioRecorder.url;
    self.audioRecorder = nil;
    
    NSError *error;
    if (![[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
        MEGALogError(@"[Voice clips] Error deactivating audio session: %@", error);
    }
    
    if (send) {
        [self.delegate messagesInputToolbar:self didRecordVoiceClipAtPath:clipURL.path];
    } else {
        if (![NSFileManager.defaultManager removeItemAtURL:clipURL error:&error]) {
            MEGALogError(@"[Voice clips] Error removing recorded clip: %@", error);
        }
    }
}

- (void)updateRecordingTimeLabel {
    NSTimeInterval interval = ([NSDate date].timeIntervalSince1970 - self.baseDate.timeIntervalSince1970);
    self.contentView.recordingTimeLabel.text = [NSString mnz_stringFromTimeInterval:interval];
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
            self.contentView.recordingView.hidden = self.contentView.recordingTimeLabel.hidden = self.contentView.slideToCancelButton.hidden = self.contentView.lockView.hidden = YES;
            
            break;
            
        case InputToolbarStateWriting: {
            UIImage *sendButton = [UIImage imageNamed:@"sendButton"];
            [self.contentView.sendButton setImage:sendButton.imageFlippedForRightToLeftLayoutDirection forState:UIControlStateNormal];
            
            break;
        }
            
        case InputToolbarStateRecordingUnlocked:
            [self.contentView.sendButton setImage:[UIImage imageNamed:@"sendVoiceClipActive"] forState:UIControlStateNormal];
            self.contentView.accessoryCameraButton.hidden = self.contentView.accessoryImageButton.hidden = self.contentView.accessoryUploadButton.hidden = self.contentView.textView.hidden = YES;
            self.contentView.recordingView.hidden = self.contentView.recordingTimeLabel.hidden = self.contentView.slideToCancelButton.hidden = self.contentView.lockView.hidden = NO;
            
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
    self.currentState = [self.contentView.textView hasText] ? InputToolbarStateWriting : InputToolbarStateInitial;
    [self updateToolbar];
    [self resizeToolbarIfNeeded];
}

- (void)resizeToolbarIfNeeded {
    self.contentView.contentViewHeightConstraint.constant = [self heightToFitInWidth:self.contentView.textView.frame.size.width];
    CGFloat newToolbarHeight = self.contentView.contentViewHeightConstraint.constant;
    if (!self.contentView.typingIndicatorView.isHidden) {
        newToolbarHeight += self.contentView.typingIndicatorView.frame.size.height;
    }
    [self.delegate messagesInputToolbar:self needsResizeToHeight:newToolbarHeight];
}

- (CGFloat)heightToFitInWidth:(CGFloat)width {
    CGFloat originalTextViewHeight = 20.0f;
    CGFloat maxTextViewHeight = 50.0f;
    CGSize sizeThatFits = [self.contentView.textView sizeThatFits:CGSizeMake(width, self.contentView.textView.frame.size.height)];
    CGFloat textViewHeightNeeded = sizeThatFits.height;
    textViewHeightNeeded = textViewHeightNeeded > maxTextViewHeight ? maxTextViewHeight : textViewHeightNeeded;
    CGFloat newToolbarHeight = kTextContentViewHeight - originalTextViewHeight + textViewHeightNeeded;
    return newToolbarHeight;
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
    
    [view.sendButton addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
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
    
    for (UIGestureRecognizer *gestureRecognizer in view.sendButton.gestureRecognizers) {
        [view.sendButton removeGestureRecognizer:gestureRecognizer];
    }
}

# pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self textViewTextDidChangeNotification:nil];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    switch (longPressGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            if (self.currentState != InputToolbarStateInitial) {
                return;
            }
            
            self.longPressInitialPoint = [longPressGestureRecognizer locationInView:self];
            self.slideToCancelOriginalFrame = self.contentView.slideToCancelButton.frame;
            self.contentView.slideToCancelButton.translatesAutoresizingMaskIntoConstraints = YES;
            
            if ([self startRecordingAudio]) {
                self.currentState = InputToolbarStateRecordingUnlocked;
                [self updateToolbar];
            }
            
            break;
            
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
            self.currentState = InputToolbarStateInitial;
            [self updateToolbar];
            
            break;
        }
            
        default:
            break;
    }
}

@end
