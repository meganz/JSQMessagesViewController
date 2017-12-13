
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
    
    [self.contentView.sendButton removeTarget:self
                                       action:NULL
                             forControlEvents:UIControlEventTouchUpInside];
    
    [self.contentView.sendButton addTarget:self
                                    action:@selector(jsq_sendButtonPressed:)
                          forControlEvents:UIControlEventTouchUpInside];

    [self updateSendButtonEnabledState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidChangeNotification:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:_contentView.textView];
}

- (MEGAToolbarContentView *)loadToolbarContentView {
    NSArray *nibViews = [[NSBundle bundleForClass:[MEGAToolbarContentView class]] loadNibNamed:NSStringFromClass([MEGAToolbarContentView class])
                                                                                         owner:nil
                                                                                       options:nil];
    return nibViews.firstObject;
}

- (void)dealloc {
    [self.contentView.sendButton removeTarget:self
                                       action:NULL
                             forControlEvents:UIControlEventTouchUpInside];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)jsq_sendButtonPressed:(UIButton *)sender {
    [self.delegate messagesInputToolbar:self didPressSendButton:sender];
}

#pragma mark - Input toolbar

- (void)updateSendButtonEnabledState {
    self.contentView.sendButton.enabled = [self.contentView.textView hasText];
    self.contentView.sendButton.backgroundColor = [self.contentView.textView hasText] ? [UIColor mnz_green00BFA5] : [UIColor mnz_grayE2EAEA];
}

#pragma mark - Notifications

- (void)textViewTextDidChangeNotification:(NSNotification *)notification {
    [self updateSendButtonEnabledState];
}

@end
