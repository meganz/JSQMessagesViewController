
#import "MEGAInputToolbar.h"

#import "UIColor+MNZCategory.h"

static void * kMEGAInputToolbarKeyValueObservingContext = &kMEGAInputToolbarKeyValueObservingContext;



@interface MEGAInputToolbar ()

@property (assign, nonatomic) BOOL jsq_isObserving;

@end



@implementation MEGAInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
    self.jsq_isObserving = NO;
    
    MEGAToolbarContentView *toolbarContentView = [self loadToolbarContentView];
    toolbarContentView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, toolbarContentView.frame.size.height);
    [self addSubview:toolbarContentView];
    _contentView = toolbarContentView;
    
    [self removeTargets];
    [self addTargets];

    [self updateSendButtonEnabledState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidChangeNotification:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:_contentView.textView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidBeginEditingNotification:)
                                                 name:UITextViewTextDidBeginEditingNotification
                                               object:_contentView.textView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidEndEditingNotification:)
                                                 name:UITextViewTextDidEndEditingNotification
                                               object:_contentView.textView];
}

- (MEGAToolbarContentView *)loadToolbarContentView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:NSStringFromClass([MEGAToolbarContentView class])
                                                                                         owner:nil
                                                                                       options:nil];
    return nibViews.firstObject;
}

- (void)dealloc {
    [self removeTargets];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)jsq_sendButtonPressed:(UIButton *)sender {
    [self.delegate messagesInputToolbar:self didPressSendButton:sender];
}

- (void)mnz_accesoryButtonPressed:(UIButton *)sender {
    [self.delegate messagesInputToolbar:self didPressAccessoryButton:sender];
}

#pragma mark - Input toolbar

- (void)updateSendButtonEnabledState {
    self.contentView.sendButton.enabled = [self.contentView.textView hasText];
    self.contentView.sendButton.backgroundColor = [self.contentView.textView hasText] ? [UIColor mnz_green00BFA5] : [UIColor mnz_grayE2EAEA];
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

- (void)addTargets {
    [self.contentView.sendButton addTarget:self
                                    action:@selector(jsq_sendButtonPressed:)
                          forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryTextButton addTarget:self
                                             action:@selector(mnz_accesoryButtonPressed:)
                                   forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryCameraButton addTarget:self
                                               action:@selector(mnz_accesoryButtonPressed:)
                                     forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryImageButton addTarget:self
                                              action:@selector(mnz_accesoryButtonPressed:)
                                    forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryUploadButton addTarget:self
                                               action:@selector(mnz_accesoryButtonPressed:)
                                     forControlEvents:UIControlEventTouchUpInside];
}

- (void)removeTargets {
    [self.contentView.sendButton removeTarget:self
                                       action:NULL
                             forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryTextButton removeTarget:self
                                                action:NULL
                                      forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryCameraButton removeTarget:self
                                                  action:NULL
                                        forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryImageButton removeTarget:self
                                                 action:NULL
                                       forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.accessoryUploadButton removeTarget:self
                                                  action:NULL
                                        forControlEvents:UIControlEventTouchUpInside];
}

@end
