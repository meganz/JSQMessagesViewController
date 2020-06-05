//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesViewController.h"

#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"

#import "JSQMessageData.h"
#import "JSQMessageBubbleImageDataSource.h"
#import "JSQMessageAvatarImageDataSource.h"

#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellOutgoing.h"

#import "JSQMessagesTypingIndicatorFooterView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"

#import "NSString+JSQMessages.h"
#import "NSBundle+JSQMessages.h"
#import <objc/runtime.h>
#import <PureLayout/PureLayout.h>
#import "MEGA-Swift.h"

// Fixes rdar://26295020
// See issue #1247 and Peter Steinberger's comment:
// https://github.com/jessesquires/JSQMessagesViewController/issues/1247#issuecomment-219386199
// Gist with workaround: https://gist.github.com/steipete/b00fc02aa9f1c66c11d0f996b1ba1265
// Forgive me
static IMP JSQReplaceMethodWithBlock(Class c, SEL origSEL, id block) {
    NSCParameterAssert(block);

    // get original method
    Method origMethod = class_getInstanceMethod(c, origSEL);
    NSCParameterAssert(origMethod);

    // convert block to IMP trampoline and replace method implementation
    IMP newIMP = imp_implementationWithBlock(block);

    // Try adding the method if not yet in the current class
    if (!class_addMethod(c, origSEL, newIMP, method_getTypeEncoding(origMethod))) {
        return method_setImplementation(origMethod, newIMP);
    } else {
        return method_getImplementation(origMethod);
    }
}

static void JSQInstallWorkaroundForSheetPresentationIssue26295020(void) {
    __block void (^removeWorkaround)(void) = ^{};
    const void (^installWorkaround)(void) = ^{
        const SEL presentSEL = @selector(presentViewController:animated:completion:);
        __block IMP origIMP = JSQReplaceMethodWithBlock(UIViewController.class, presentSEL, ^(UIViewController *self, id vC, BOOL animated, id completion) {
            UIViewController *targetVC = self;
            while (targetVC.presentedViewController) {
                targetVC = targetVC.presentedViewController;
            }
            ((void (*)(id, SEL, id, BOOL, id))origIMP)(targetVC, presentSEL, vC, animated, completion);
        });
        removeWorkaround = ^{
            Method origMethod = class_getInstanceMethod(UIViewController.class, presentSEL);
            NSCParameterAssert(origMethod);
            class_replaceMethod(UIViewController.class,
                                presentSEL,
                                origIMP,
                                method_getTypeEncoding(origMethod));
        };
    };

    const SEL presentSheetSEL = NSSelectorFromString(@"presentSheetFromRect:");
    const void (^swizzleOnClass)(Class k) = ^(Class klass) {
        const __block IMP origIMP = JSQReplaceMethodWithBlock(klass, presentSheetSEL, ^(id self, CGRect rect) {
            // Before calling the original implementation, we swizzle the presentation logic on UIViewController
            installWorkaround();
            // UIKit later presents the sheet on [view.window rootViewController];
            // See https://github.com/WebKit/webkit/blob/1aceb9ed7a42d0a5ed11558c72bcd57068b642e7/Source/WebKit2/UIProcess/ios/WKActionSheet.mm#L102
            // Our workaround forwards this to the topmost presentedViewController instead.
            ((void (*)(id, SEL, CGRect))origIMP)(self, presentSheetSEL, rect);
            // Cleaning up again - this workaround would swallow bugs if we let it be there.
            removeWorkaround();
        });
    };

    // _UIRotatingAlertController
    Class alertClass = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"_U", @"IRotat", @"ingAlertController"]);
    if (alertClass) {
        swizzleOnClass(alertClass);
    }

    // WKActionSheet
    Class actionSheetClass = NSClassFromString([NSString stringWithFormat:@"%@%@%@", @"W", @"KActio", @"nSheet"]);
    if (actionSheetClass) {
        swizzleOnClass(actionSheetClass);
    }
}

extern const CGFloat kTextContentViewHeight;

@interface JSQMessagesViewController () <MEGAInputToolbarDelegate>

@property (weak, nonatomic) IBOutlet JSQMessagesCollectionView *collectionView;
@property (strong, nonatomic) IBOutlet MEGAInputToolbar *inputToolbar;

@property (strong, nonatomic) NSIndexPath *selectedIndexPathForMenu;

@end


@implementation JSQMessagesViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesViewController class])
                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (instancetype)messagesViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([JSQMessagesViewController class])
                                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (void)initialize {
    [super initialize];
    if (self == [JSQMessagesViewController self]) {
        JSQInstallWorkaroundForSheetPresentationIssue26295020();
    }
}

#pragma mark - Initialization

- (void)jsq_configureMessagesViewController
{
    self.view.backgroundColor = [UIColor whiteColor];

    self.toolbarHeightConstraint.constant = self.inputToolbar.frame.size.height + [self safeAreaInsetsBottomPadding];

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    self.inputToolbar.delegate = self;
    self.inputToolbar.contentView.textView.placeHolder = [NSBundle jsq_localizedStringForKey:@"new_message"];
    self.inputToolbar.contentView.textView.accessibilityLabel = [NSBundle jsq_localizedStringForKey:@"new_message"];
    self.inputToolbar.contentView.textView.delegate = self;
    self.inputToolbar.contentView.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [self.inputToolbar removeFromSuperview];
    
    self.recordView = MEGARecordView.recordView;
    [self.view addSubview:self.recordView];
    [self.recordView autoSetDimensionsToSize:CGSizeMake(180, 180)];
    [self.recordView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.view withOffset:-44];
    [self.recordView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    self.inputToolbar.recordView = self.recordView;
    self.recordView.hidden = YES;

    self.outgoingCellIdentifier = [JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier];
    self.outgoingMediaCellIdentifier = [JSQMessagesCollectionViewCellOutgoing mediaCellReuseIdentifier];

    self.incomingCellIdentifier = [JSQMessagesCollectionViewCellIncoming cellReuseIdentifier];
    self.incomingMediaCellIdentifier = [JSQMessagesCollectionViewCellIncoming mediaCellReuseIdentifier];

    // NOTE: let this behavior be opt-in for now
    // [JSQMessagesCollectionViewCell registerMenuAction:@selector(delete:)];

    self.showTypingIndicator = NO;

    self.showLoadEarlierMessagesHeader = NO;

    self.additionalContentInset = UIEdgeInsetsZero;

    [self jsq_updateCollectionViewInsets];
}

- (void)dealloc
{
    [self jsq_registerForNotifications:NO];

    _collectionView.dataSource = nil;
    _collectionView.delegate = nil;

    _inputToolbar.contentView.textView.delegate = nil;
    _inputToolbar.delegate = nil;
}

#pragma mark - Setters

- (void)setShowTypingIndicator:(BOOL)showTypingIndicator
{
    if (_showTypingIndicator == showTypingIndicator) {
        return;
    }

    _showTypingIndicator = showTypingIndicator;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)setShowLoadEarlierMessagesHeader:(BOOL)showLoadEarlierMessagesHeader
{
    if (_showLoadEarlierMessagesHeader == showLoadEarlierMessagesHeader) {
        return;
    }

    _showLoadEarlierMessagesHeader = showLoadEarlierMessagesHeader;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView reloadData];
}

- (void)setAdditionalContentInset:(UIEdgeInsets)additionalContentInset
{
    _additionalContentInset = additionalContentInset;
    [self jsq_updateCollectionViewInsets];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[[self class] nib] instantiateWithOwner:self options:nil];

    [self jsq_configureMessagesViewController];
    [self jsq_registerForNotifications:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.inputToolbar.contentView.textView.hasText) {
        self.toolbarHeightConstraint.constant = self.inputToolbar.frame.size.height + [self safeAreaInsetsBottomPadding];
    }
    [self.view layoutIfNeeded];
    [self.collectionView.collectionViewLayout invalidateLayout];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.collectionView.collectionViewLayout.springinessEnabled = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

#pragma mark - View rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    if (self.showTypingIndicator) {
        self.showTypingIndicator = NO;
        self.showTypingIndicator = YES;
        [self.collectionView reloadData];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self jsq_resetLayoutAndCaches];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self jsq_resetLayoutAndCaches];
}

- (void)jsq_resetLayoutAndCaches
{
    JSQMessagesCollectionViewFlowLayoutInvalidationContext *context = [JSQMessagesCollectionViewFlowLayoutInvalidationContext context];
    context.invalidateFlowLayoutMessagesCache = YES;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:context];
}

#pragma mark - Messages view controller

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)didPressAccessoryButton:(UIButton *)sender
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)didPressJoinButton:(UIButton *)sender
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)didChangeToState:(InputToolbarState)state
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)finishSendingMessage
{
    [self finishSendingMessageAnimated:YES];
}

- (void)finishSendingMessageAnimated:(BOOL)animated {

    UITextView *textView = self.inputToolbar.contentView.textView;
    textView.text = nil;
    [textView.undoManager removeAllActions];

    [self scrollToBottomAnimated:animated];
}

- (void)finishReceivingMessage
{
    [self finishReceivingMessageAnimated:YES];
}

- (void)finishReceivingMessageAnimated:(BOOL)animated {

    self.showTypingIndicator = NO;

    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView reloadData];

    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [NSBundle jsq_localizedStringForKey:@"new_message_received_accessibility_announcement"]);
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] == 0) {
        return;
    }

    NSIndexPath *lastCell = [NSIndexPath indexPathForItem:([self.collectionView numberOfItemsInSection:0] - 1) inSection:0];

    [UIView animateWithDuration:animated ? 0.3 : 0.0 animations:^{
        [self scrollToIndexPath:lastCell animated:NO];
    }];
}


- (void)scrollToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] <= indexPath.section) {
        return;
    }

    NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:indexPath.section];
    if (numberOfItems == 0) {
        return;
    }

    CGFloat collectionViewContentHeight = [self.collectionView.collectionViewLayout collectionViewContentSize].height;
    BOOL isContentTooSmall = (collectionViewContentHeight < CGRectGetHeight(self.collectionView.bounds));

    if (isContentTooSmall) {
        //  workaround for the first few messages not scrolling
        //  when the collection view content size is too small, `scrollToItemAtIndexPath:` doesn't work properly
        //  this seems to be a UIKit bug, see #256 on GitHub
        [self.collectionView scrollRectToVisible:CGRectMake(0.0, collectionViewContentHeight - 1.0f, 1.0f, 1.0f)
                                        animated:animated];
        return;
    }

    NSInteger item = MAX(MIN(indexPath.item, numberOfItems - 1), 0);
    indexPath = [NSIndexPath indexPathForItem:item inSection:0];

    //  workaround for really long messages not scrolling
    //  if last message is too long, use scroll position bottom for better appearance, else use top
    //  possibly a UIKit bug, see #480 on GitHub
    CGSize cellSize = [self.collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
    CGFloat maxHeightForVisibleMessage = CGRectGetHeight(self.collectionView.bounds)
    - self.collectionView.contentInset.top
    - self.collectionView.contentInset.bottom
    - CGRectGetHeight(self.inputToolbar.bounds);
    UICollectionViewScrollPosition scrollPosition = (cellSize.height > maxHeightForVisibleMessage) ? UICollectionViewScrollPositionBottom : UICollectionViewScrollPositionTop;

    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:scrollPosition
                                        animated:animated];
}

- (BOOL)isOutgoingMessage:(id<JSQMessageData>)messageItem
{
    NSString *messageSenderId = [messageItem senderId];
    NSParameterAssert(messageSenderId != nil);

    return [messageSenderId isEqualToString:[self.collectionView.dataSource senderId]];
}

- (BOOL)canRecordAudio {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
    return NO;
}

#pragma mark - JSQMessages collection view data source

- (NSString *)senderDisplayName
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (NSString *)senderId
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForUnreadMessagesLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - Collection view data source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<JSQMessageData> messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    NSParameterAssert(messageItem != nil);

    BOOL isOutgoingMessage = [self isOutgoingMessage:messageItem];
    BOOL isMediaMessage = [messageItem isMediaMessage];

    NSString *cellIdentifier = nil;
    if (isMediaMessage) {
        cellIdentifier = isOutgoingMessage ? self.outgoingMediaCellIdentifier : self.incomingMediaCellIdentifier;
    }
    else {
        cellIdentifier = isOutgoingMessage ? self.outgoingCellIdentifier : self.incomingCellIdentifier;
    }

    JSQMessagesCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.accessibilityIdentifier = [NSString stringWithFormat:@"(%ld, %ld)", (long)indexPath.section, (long)indexPath.row];
    cell.delegate = collectionView;

    if (!isMediaMessage) {
        cell.textView.text = [messageItem text];
        NSParameterAssert(cell.textView.text != nil);

        id<JSQMessageBubbleImageDataSource> bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
        cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
        cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
    }
    else {
        id<JSQMessageMediaData> messageMedia = [messageItem media];
        cell.mediaView = [messageMedia mediaView] ?: [messageMedia mediaPlaceholderView];
        NSParameterAssert(cell.mediaView != nil);
    }

    BOOL needsAvatar = YES;
    if (isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.outgoingAvatarViewSize, CGSizeZero)) {
        needsAvatar = NO;
    }
    else if (!isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.incomingAvatarViewSize, CGSizeZero)) {
        needsAvatar = NO;
    }

    id<JSQMessageAvatarImageDataSource> avatarImageDataSource = nil;
    if (needsAvatar) {
        avatarImageDataSource = [collectionView.dataSource collectionView:collectionView avatarImageDataForItemAtIndexPath:indexPath];
        if (avatarImageDataSource != nil) {

            UIImage *avatarImage = [avatarImageDataSource avatarImage];
            if (avatarImage == nil) {
                cell.avatarImageView.image = [avatarImageDataSource avatarPlaceholderImage];
                cell.avatarImageView.highlightedImage = nil;
            }
            else {
                cell.avatarImageView.image = avatarImage;
                cell.avatarImageView.highlightedImage = [avatarImageDataSource avatarHighlightedImage];
            }
        }
    }

    cell.unreadMessagesLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForUnreadMessagesLabelAtIndexPath:indexPath];
    cell.cellTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];
    cell.messageBubbleTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:indexPath];
    cell.cellBottomLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellBottomLabelAtIndexPath:indexPath];

    cell.cellTopLabel.textInsets = UIEdgeInsetsMake(13.0f, 0.0f, 0.0f, 0.0f);
    
    BOOL isRTLLanguage = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    if (isOutgoingMessage) {
        cell.messageBubbleTopLabel.textInsets = isRTLLanguage ? UIEdgeInsetsMake(0.0f, 4.0f, 0.0f, 0.0f) : UIEdgeInsetsMake(0.0f, -4.0f, 0.0f, 0.0f);
    }
    else {
        cell.messageBubbleTopLabel.textInsets = isRTLLanguage ? UIEdgeInsetsMake(0.0f, -28.0f, 0.0f, 0.0f) : UIEdgeInsetsMake(0.0f, 28.0f, 0.0f, 0.0f);
    }

    cell.textView.dataDetectorTypes = UIDataDetectorTypeAll;

    cell.backgroundColor = [UIColor clearColor];
    cell.layer.rasterizationScale = [UIScreen mainScreen].scale;
    cell.layer.shouldRasterize = YES;
    [self collectionView:collectionView accessibilityForCell:cell indexPath:indexPath message:messageItem];

    return cell;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
  accessibilityForCell:(JSQMessagesCollectionViewCell*)cell
             indexPath:(NSIndexPath *)indexPath
               message:(id<JSQMessageData>)messageItem
{
    const BOOL isMediaMessage = [messageItem isMediaMessage];
    cell.isAccessibilityElement = YES;
    if (!isMediaMessage) {
        cell.accessibilityLabel = [NSString stringWithFormat:[NSBundle jsq_localizedStringForKey:@"text_message_accessibility_label"],
                                   [messageItem senderDisplayName],
                                   [messageItem text]];
    }
    else {
        cell.accessibilityLabel = [NSString stringWithFormat:[NSBundle jsq_localizedStringForKey:@"media_message_accessibility_label"],
                                   [messageItem senderDisplayName]];
    }
}

- (UICollectionReusableView *)collectionView:(JSQMessagesCollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if (self.showTypingIndicator && [kind isEqualToString:UICollectionElementKindSectionFooter]) {
        return [collectionView dequeueTypingIndicatorFooterViewForIndexPath:indexPath];
    }
    else if (self.showLoadEarlierMessagesHeader && [kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return [collectionView dequeueLoadEarlierMessagesViewHeaderForIndexPath:indexPath];
    }

    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.showTypingIndicator) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesTypingIndicatorFooterViewHeight);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (!self.showLoadEarlierMessagesHeader) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesLoadEarlierHeaderViewHeight);
}

#pragma mark - Collection view delegate

- (BOOL)collectionView:(JSQMessagesCollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //  disable menu for media messages
    id<JSQMessageData> messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    if ([messageItem isMediaMessage]) {

        if ([[messageItem media] respondsToSelector:@selector(mediaDataType)]) {
            return YES;
        }
        return NO;
    }

    self.selectedIndexPathForMenu = indexPath;

    //  textviews are selectable to allow data detectors
    //  however, this allows the 'copy, define, select' UIMenuController to show
    //  which conflicts with the collection view's UIMenuController
    //  temporarily disable 'selectable' to prevent this issue
    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    selectedCell.textView.selectable = NO;
    
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:) || action == @selector(delete:)) {
        return YES;
    }

    return NO;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) {

        id<JSQMessageData> messageData = [self collectionView:collectionView messageDataForItemAtIndexPath:indexPath];

        if ([messageData isMediaMessage]) {
            id<JSQMessageMediaData> mediaData = [messageData media];
            if ([messageData conformsToProtocol:@protocol(JSQMessageData)]) {
                [[UIPasteboard generalPasteboard] setValue:[mediaData mediaData]
                                         forPasteboardType:[mediaData mediaDataType]];
            }
        } else {
            [[UIPasteboard generalPasteboard] setString:[messageData text]];
        }
    }
    else if (action == @selector(delete:)) {
        [collectionView.dataSource collectionView:collectionView didDeleteMessageAtIndexPath:indexPath];

        [collectionView deleteItemsAtIndexPaths:@[indexPath]];
        [collectionView.collectionViewLayout invalidateLayout];
    }
}

#pragma mark - Collection view delegate flow layout

- (CGSize)collectionView:(JSQMessagesCollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionViewLayout sizeForItemAtIndexPath:indexPath];
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForUnreadMessagesLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapAvatarImageView:(UIImageView *)avatarImageView
           atIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapCellAtIndexPath:(NSIndexPath *)indexPath
         touchLocation:(CGPoint)touchLocation { }

#pragma mark - Input toolbar delegate

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didPressSendButton:(UIButton *)sender
{
    [self didPressSendButton:sender
             withMessageText:[self jsq_currentlyComposedMessageText]
                    senderId:[self.collectionView.dataSource senderId]
           senderDisplayName:[self.collectionView.dataSource senderDisplayName]
                        date:[NSDate date]];
    self.toolbarHeightConstraint.constant = kTextContentViewHeight + [self safeAreaInsetsBottomPadding];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didPressSendButton:(UIButton *)sender toAttachAssets:(NSArray<PHAsset *> *)assets {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didPressNotHeldRecordButton:(UIButton *)sender {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didRecordVoiceClipAtPath:(NSString *)voiceClipPath {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar assetLoadFailed:(NSError *)error {    
    NSString *message = [[[[[error.userInfo objectForKey:@"NSUnderlyingError"] userInfo] objectForKey:@"NSUnderlyingError"] userInfo] objectForKey:@"NSLocalizedDescription"];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"error", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didPressAccessoryButton:(UIButton *)sender {
    [self didPressAccessoryButton:sender];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didPressJoinButton:(UIButton *)sender {
    [self didPressJoinButton:sender];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didChangeToState:(InputToolbarState)state {
    switch (state) {
        case InputToolbarStateInitial:
            self.recordView.hidden = YES;
            break;
        case InputToolbarStateRecordingUnlocked:
            self.recordView.hidden = NO;
        default:
            break;
    }
    [self didChangeToState:state];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar needsResizeToHeight:(CGFloat)newToolbarHeight {
    
    
    [UIView animateWithDuration:0.3 animations:^{
        self.toolbarHeightConstraint.constant = newToolbarHeight + [self safeAreaInsetsBottomPadding];
    }];
}

- (void)messagesInputToolbar:(MEGAInputToolbar *)toolbar didLoadContentView:(MEGAToolbarContentView *)toolbarContentView {
    [self customToolbarContentView];
}

- (BOOL)messagesInputToolbarCanRecordVoiceClip:(MEGAInputToolbar *_Nonnull)toolbar {
    return [self canRecordAudio];
}

- (NSString *)jsq_currentlyComposedMessageText
{
    //  auto-accept any auto-correct suggestions
    [self.inputToolbar.contentView.textView.inputDelegate selectionWillChange:self.inputToolbar.contentView.textView];
    [self.inputToolbar.contentView.textView.inputDelegate selectionDidChange:self.inputToolbar.contentView.textView];

    return [self.inputToolbar.contentView.textView.text jsq_stringByTrimingWhitespace];
}

- (void)customToolbarContentView {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

#pragma mark - Input

- (UIView *)inputAccessoryView
{
    return self.inputToolbar;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark - Text view delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView becomeFirstResponder];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView resignFirstResponder];
}

#pragma mark - Notifications

- (void)didReceiveMenuWillShowNotification:(NSNotification *)notification
{
    if (!self.selectedIndexPathForMenu) {
        return;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIMenuControllerWillShowMenuNotification
                                                  object:nil];

    UIMenuController *menu = [notification object];
    [menu setMenuVisible:NO animated:NO];

    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
    CGRect selectedCellMessageBubbleFrame = [selectedCell convertRect:selectedCell.messageBubbleContainerView.frame toView:self.view];

    [menu setTargetRect:selectedCellMessageBubbleFrame inView:self.view];
    [menu setMenuVisible:YES animated:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMenuWillShowNotification:)
                                                 name:UIMenuControllerWillShowMenuNotification
                                               object:nil];
}

- (void)didReceiveMenuWillHideNotification:(NSNotification *)notification
{
    if (!self.selectedIndexPathForMenu) {
        return;
    }

    //  per comment above in 'shouldShowMenuForItemAtIndexPath:'
    //  re-enable 'selectable', thus re-enabling data detectors if present
    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
    selectedCell.textView.selectable = YES;
    self.selectedIndexPathForMenu = nil;
}

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView setNeedsLayout];
}

#pragma mark - Collection view utilities

- (void)jsq_updateCollectionViewInsets
{
    const CGFloat top = self.additionalContentInset.top;
    const CGFloat bottom = CGRectGetMaxY(self.collectionView.frame) - CGRectGetMinY(self.inputToolbar.frame) + self.additionalContentInset.bottom;
    [self jsq_setCollectionViewInsetsTopValue:top bottomValue:bottom];
}

- (void)jsq_setCollectionViewInsetsTopValue:(CGFloat)top bottomValue:(CGFloat)bottom
{
    UIEdgeInsets insets = UIEdgeInsetsMake(self.topLayoutGuide.length + top, 0.0f, bottom, 0.0f);
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
}

- (BOOL)jsq_isMenuVisible
{
    //  check if cell copy menu is showing
    //  it is only our menu if `selectedIndexPathForMenu` is not `nil`
    return self.selectedIndexPathForMenu != nil && [[UIMenuController sharedMenuController] isMenuVisible];
}

#pragma mark - Utilities

- (void)jsq_registerForNotifications:(BOOL)registerForNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (registerForNotifications) {
        [center addObserver:self
                   selector:@selector(jsq_didReceiveKeyboardWillChangeFrameNotification:)
                       name:UIKeyboardWillChangeFrameNotification
                     object:nil];

        [center addObserver:self
                   selector:@selector(didReceiveMenuWillShowNotification:)
                       name:UIMenuControllerWillShowMenuNotification
                     object:nil];

        [center addObserver:self
                   selector:@selector(didReceiveMenuWillHideNotification:)
                       name:UIMenuControllerWillHideMenuNotification
                     object:nil];

        [center addObserver:self
                   selector:@selector(preferredContentSizeChanged:)
                       name:UIContentSizeCategoryDidChangeNotification
                     object:nil];
    }
    else {
        [center removeObserver:self
                          name:UIKeyboardWillChangeFrameNotification
                        object:nil];

        [center removeObserver:self
                          name:UIMenuControllerWillShowMenuNotification
                        object:nil];

        [center removeObserver:self
                          name:UIMenuControllerWillHideMenuNotification
                        object:nil];

        [center removeObserver:self
                          name:UIContentSizeCategoryDidChangeNotification
                        object:nil];
    }
}

- (void)jsq_didReceiveKeyboardWillChangeFrameNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    
    CGRect keyboardEndFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    if (CGRectIsNull(keyboardEndFrame)) {
        return;
    }
    
    CGFloat safeAreaBottomInset = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeAreaBottomInset = UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    }
    
    UIViewAnimationCurve animationCurve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSInteger animationCurveOption = (animationCurve << 16);
    
    double animationDuration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:animationDuration
                          delay:0.0
                        options:animationCurveOption
                     animations:^{
                         const UIEdgeInsets insets = self.additionalContentInset;
                         [self jsq_setCollectionViewInsetsTopValue:insets.top
                                                       bottomValue:CGRectGetHeight(keyboardEndFrame) + insets.bottom - safeAreaBottomInset];
                     }
                     completion:nil];
}

#pragma mark - IBActions

- (IBAction)closeTooltipTapped:(UIButton *)sender {
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

#pragma mark - Private

- (CGFloat)safeAreaInsetsBottomPadding {
    CGFloat bottomPadding = 0;
    if (@available(iOS 11.0, *)) {
        if (!self.inputToolbar.contentView.textView.isFirstResponder) {
            bottomPadding = UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
        }
    }
    return bottomPadding;
}

@end
