
#import "MEGAInputToolbar.h"

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



@interface MEGAInputToolbar ()

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (nonatomic) MEGAToolbarAssetPicker *assetPicker;
@property (nonatomic) MEGAToolbarSelectedAssets *selectedAssets;
@property (nonatomic) NSMutableArray<PHAsset *> *selectedAssetsArray;

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
    
    [self updateSendButtonEnabledState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidChangeNotification:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:textContentView.textView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidBeginEditingNotification:)
                                                 name:UITextViewTextDidBeginEditingNotification
                                               object:textContentView.textView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidEndEditingNotification:)
                                                 name:UITextViewTextDidEndEditingNotification
                                               object:textContentView.textView];
    
    // Observe remote changes of the text within the textView, useful when the user edits the content of a message:
    [textContentView.textView addObserver:self forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:nil];
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

- (void)jsq_sendButtonPressed:(UIButton *)sender {
    if (self.contentView) {
        [self.delegate messagesInputToolbar:self didPressSendButton:sender];
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
            } else {
                if ([self.contentView.textView isFirstResponder]) {
                    [self.contentView.textView resignFirstResponder];
                } else {
                    [self.contentView.textView becomeFirstResponder];
                }
            }
            [self.delegate messagesInputToolbar:self didPressAccessoryButton:sender];
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

#pragma mark - Input toolbar

- (void)updateSendButtonEnabledState {
    self.contentView.sendButton.enabled = [self.contentView.textView hasText];
    self.contentView.sendButton.backgroundColor = [self.contentView.textView hasText] ? [UIColor mnz_green00BFA5] : [UIColor mnz_grayE2EAEA];
}

#pragma mark - MEGAToolbarAssetPickerDelegate

- (void)assetPicker:(MEGAToolbarAssetPicker *)assetPicker didChangeSelectionTo:(NSMutableArray<PHAsset *> *)selectedAssetsArray {
    self.imagePickerView.sendButton.enabled = selectedAssetsArray.count > 0;
    self.imagePickerView.sendButton.backgroundColor = selectedAssetsArray.count > 0 ? [UIColor mnz_green00BFA5] : [UIColor mnz_grayE2EAEA];
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
    [self updateSendButtonEnabledState];
    [self resizeToolbarIfNeeded];
}

- (void)textViewTextDidBeginEditingNotification:(NSNotification *)notification {
    self.contentView.accessoryTextButton.tintColor = [UIColor mnz_green00BFA5];
}

- (void)textViewTextDidEndEditingNotification:(NSNotification *)notification {
    self.contentView.accessoryTextButton.tintColor = [UIColor mnz_gray999999];
}

- (void)resizeToolbarIfNeeded {
    [self.delegate messagesInputToolbar:self needsResizeToHeight:[self heightToFitInWidth:self.contentView.textView.frame.size.width]];
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

    [view.accessoryTextButton addTarget:self
                                 action:@selector(mnz_accesoryButtonPressed:)
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
}

- (void)removeTargetsFromView:(MEGAToolbarContentView *)view {
    [view.sendButton removeTarget:self
                           action:NULL
                 forControlEvents:UIControlEventTouchUpInside];
    
    [view.accessoryTextButton removeTarget:self
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
}

# pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self textViewTextDidChangeNotification:nil];
}

@end
