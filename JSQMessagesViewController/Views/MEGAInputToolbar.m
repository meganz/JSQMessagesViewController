
#import "MEGAInputToolbar.h"

#import "UIColor+MNZCategory.h"

static void * kMEGAInputToolbarKeyValueObservingContext = &kMEGAInputToolbarKeyValueObservingContext;

const CGFloat kTextContentViewHeight = 100.0f;
const CGFloat kImagePickerViewHeight = 383.0f;



@interface MEGAInputToolbar ()

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (nonatomic) MEGAToolbarAssetPicker *assetPicker;
@property (nonatomic) NSArray<PHAsset *> *assetsArray;

@end



@implementation MEGAInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
    self.jsq_isObserving = NO;
    
    _contentView = [self loadToolbarTextContentView];
}

- (void)layoutSubviews {
    if (self.frame.size.width > [UIScreen mainScreen].bounds.size.width) {
        if (self.contentView) {
            self.contentView.frame = self.frame = CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.width, kTextContentViewHeight);
        } else {
            self.imagePickerView.frame = self.frame = CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.width, kImagePickerViewHeight);
        }
    }
}

- (MEGAToolbarContentView *)loadToolbarTextContentView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:@"MEGAToolbarTextContentView"
                                                                                         owner:nil
                                                                                       options:nil];
    MEGAToolbarContentView *textContentView = nibViews.firstObject;
    [self setupTextContentView:textContentView];
    return textContentView;
}

- (MEGAToolbarContentView *)loadToolbarImagePickerView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:@"MEGAToolbarImagePickerView"
                                                                                         owner:nil
                                                                                       options:nil];
    MEGAToolbarContentView *imagePickerView = nibViews.firstObject;
    [self setupImagePickerView:imagePickerView];
    return imagePickerView;
}

- (void)setupTextContentView:(MEGAToolbarContentView *)textContentView {
    textContentView.frame = self.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, kTextContentViewHeight);
    [self addSubview:textContentView];
    [self removeTargetsFromView:textContentView];
    [self addTargetsToView:textContentView];
    [self.delegate messagesInputToolbar:self needsResizeToHeight:kTextContentViewHeight];
    
    textContentView.textView.placeHolderTextColor = [UIColor mnz_grayCCCCCC];
    textContentView.textView.placeHolder = AMLocalizedString(@"writeAMessage", @"Message box label which shows that user can type message text in this textview");
    textContentView.textView.font = [UIFont mnz_SFUIRegularWithSize:15.0f];
    textContentView.textView.textColor = [UIColor mnz_black333333];
    textContentView.textView.tintColor = [UIColor mnz_green00BFA5];
    
    textContentView.textView.placeHolder = AMLocalizedString(@"writeAMessage", @"Message box label which shows that user can type message text in this textview");

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
    
    // Disable the image accessory button if the app does not have permission to access the multimedia files:
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied || [PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted) {
        textContentView.accessoryImageButton.enabled = NO;
    }
}

- (void)setupImagePickerView:(MEGAToolbarContentView *)imagePickerView {
    imagePickerView.frame = self.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, kImagePickerViewHeight);
    [self addSubview:imagePickerView];
    [self removeTargetsFromView:imagePickerView];
    [self addTargetsToView:imagePickerView];
    [self.delegate messagesInputToolbar:self needsResizeToHeight:kImagePickerViewHeight];

    self.assetPicker = [[MEGAToolbarAssetPicker alloc] initWithCollectionView:imagePickerView.collectionView delegate:self];
    imagePickerView.collectionView.dataSource = self.assetPicker;
    imagePickerView.collectionView.delegate = self.assetPicker;
}

- (void)dealloc {
    if (self.contentView) {
        [self removeTargetsFromView:self.contentView];
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
        [self.delegate messagesInputToolbar:self didPressSendButton:sender toAttachAssets:self.assetsArray];
        [self.assetPicker resetSelection];
        [self mnz_accesoryButtonPressed:self.imagePickerView.accessoryTextButton];
    }
}

- (void)mnz_accesoryButtonPressed:(UIButton *)sender {
    switch (sender.tag) {
        case MEGAChatAccessoryButtonImage:
            if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
                        if (!self.imagePickerView) {
                            [self.contentView removeFromSuperview];
                            _imagePickerView = [self loadToolbarImagePickerView];
                        }
                    } else {
                        self.contentView.accessoryImageButton.enabled = NO;
                    }
                }];
            } else {
                if (!self.imagePickerView) {
                    [self.contentView removeFromSuperview];
                    _imagePickerView = [self loadToolbarImagePickerView];
                }
            }
            break;
            
        default:
            if (self.imagePickerView) {
                [self.imagePickerView removeFromSuperview];
                _contentView = [self loadToolbarTextContentView];
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

- (void)assetPicker:(MEGAToolbarAssetPicker *)assetPicker didChangeSelectionTo:(NSArray<PHAsset *> *)assetsArray {
    self.imagePickerView.sendButton.enabled = assetsArray.count > 0;
    self.imagePickerView.sendButton.backgroundColor = assetsArray.count > 0 ? [UIColor mnz_green00BFA5] : [UIColor mnz_grayE2EAEA];
    self.assetsArray = assetsArray;
    self.imagePickerView.textView.text = [NSString stringWithFormat:AMLocalizedString(@"files", nil), assetsArray.count];
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
    CGFloat originalTextViewHeight = 18.0f;
    CGFloat originalToolbarHeight = 100.0f;
    CGFloat maxTextViewHeight = 54.0f;
    CGSize sizeThatFits = [self.contentView.textView sizeThatFits:self.contentView.textView.frame.size];
    CGFloat textViewHeightNeeded = sizeThatFits.height;
    if (textViewHeightNeeded > maxTextViewHeight) {
        return;
    }
    CGFloat newToolbarHeight = originalToolbarHeight - originalTextViewHeight + textViewHeightNeeded;
    [self.delegate messagesInputToolbar:self needsResizeToHeight:newToolbarHeight];
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

@end
