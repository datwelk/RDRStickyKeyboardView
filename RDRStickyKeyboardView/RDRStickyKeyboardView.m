//
//  RDRStickyKeyboardView.m
//
//  Created by Damiaan Twelker on 17/01/14.
//  Copyright (c) 2014 Damiaan Twelker. All rights reserved.
//
//  LICENSE
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Damiaan Twelker
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "RDRStickyKeyboardView.h"

#pragma mark - Convenience methods

/*
 * @param keyboardFrame The frame of the keyboard whose size
 * is to be compared. This frame should be in window coordinates.
 * @param inputViewBounds The bounds of the input view whose
 * size is to be compared.
 *
 * @return A boolean indicating whether keyboardFrame
 * and inputViewBounds have equal sizes.
 */
static BOOL RDRKeyboardSizeEqualsInputViewSize(CGRect keyboardFrame,
                                               CGRect inputViewBounds) {
    // Convert keyboardFrame
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    CGRect convertedRect = [view convertRect:keyboardFrame
                                    fromView:nil];
    
    if (CGSizeEqualToSize(convertedRect.size, inputViewBounds.size)) {
        return YES;
    }
    
    return NO;
}

/*
 * @param beginFrame The keyboard's frame in window coordinates
 * before the animation.
 * @param endFrame The keyboard's frame in window coordinates
 * after the animation.
 *
 * @return A boolean indicating whether the difference
 * between the y coordinate of beginFrame and the y coordinate
 * of endFrame equal the height of endFrame after converting
 * both parameters to view coordinates.
 */
static BOOL RDRKeyboardFrameChangeEqualsKeyboardHeight(CGRect beginFrame,
                                                       CGRect endFrame) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    
    // Convert the begin frame to view coordinates
    CGRect beginFrameConverted = [view convertRect:beginFrame
                                          fromView:nil];
    
    // Convert the end frame to view coordinates
    CGRect endFrameConverted = [view convertRect:endFrame
                                        fromView:nil];
    
    // New and old keyboard origin should differ exactly
    // one keyboard height
    if (fabs(endFrameConverted.origin.y - beginFrameConverted.origin.y)
        != endFrameConverted.size.height) {
        return NO;
    }
    
    return YES;
}

static BOOL RDRKeyboardFrameChangeEqualsInputViewHeight(CGRect beginFrame,
                                                        CGRect endFrame,
                                                        CGRect inputViewBounds) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    
    // Convert the begin frame to view coordinates
    CGRect beginFrameConverted = [view convertRect:beginFrame
                                          fromView:nil];
    
    // Convert the end frame to view coordinates
    CGRect endFrameConverted = [view convertRect:endFrame
                                        fromView:nil];
    
    // New and old keyboard origin should differ exactly
    // one keyboard height
    if (fabs(endFrameConverted.origin.y - beginFrameConverted.origin.y)
        != inputViewBounds.size.height) {
        return NO;
    }
    
    return YES;
}

/*
 * @param keyboardFrame The frame of the keyboard in
 * window coordinates.
 *
 * @return A boolean indicating whether the keyboard
 * is completely visible AND positioned at the bottom
 * of the window.
 */
static BOOL RDRKeyboardIsFullyShown(CGRect keyboardFrame) {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    CGRect convertedRect = [view convertRect:keyboardFrame
                                    fromView:nil];
    
    if ((view.bounds.size.height - convertedRect.size.height)
        != convertedRect.origin.y) {
        return NO;
    }
    
    return YES;
}

/*
 * @param keyboardFrame The frame of the keyboard in
 * window coordinates.
 *
 * @return A boolean indicating whether given keyboardFrame's
 * y coordinate equals the height of the view it is compared
 * with, after having been converted to view coordinates.
 */
static BOOL RDRKeyboardIsFullyHidden(CGRect keyboardFrame) {
    // The window's rootViewController's view
    // is fullscreen.
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    
    // Convert rect to view coordinates, which will
    // adjust the frame for rotation.
    CGRect convertedRect = [view convertRect:keyboardFrame
                                    fromView:nil];
    
    // Compare against the view's bounds, NOT the frame
    // since the bounds are adjusted to rotation.
    if (view.bounds.size.height != convertedRect.origin.y) {
        return NO;
    }
    
    return YES;
}

/*
 * @param textView A UITextView instance whose height
 * should be calculated if no text is wrapped.
 *
 * @return A CGFloat value indicating the height
 * the UITextView instance should be if all text
 * is visible.
 */
static inline CGFloat RDRTextViewHeight(UITextView *textView) {
    NSTextContainer *textContainer = textView.textContainer;
    CGRect textRect =
    [textView.layoutManager usedRectForTextContainer:textContainer];
    
    CGFloat textViewHeight = textRect.size.height +
    textView.textContainerInset.top + textView.textContainerInset.bottom;
    
    return textViewHeight;
}

static CGFloat RDRContentOffsetForBottom(UIScrollView *scrollView) {
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat scrollViewHeight = scrollView.bounds.size.height;
    
    UIEdgeInsets contentInset = scrollView.contentInset;
    CGFloat bottomInset = contentInset.bottom;
    CGFloat topInset = contentInset.top;
    
    CGFloat contentOffsetY;
    contentOffsetY = contentHeight - (scrollViewHeight - bottomInset);
    contentOffsetY = MAX(contentOffsetY, -topInset);
    
    return contentOffsetY;
}

static inline UIViewAnimationOptions RDRAnimationOptionsForCurve(UIViewAnimationCurve curve) {
    return (curve << 16 | UIViewAnimationOptionBeginFromCurrentState);
}

#pragma mark - RDRKeyboardInputView

#define RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL                     5
#define RDR_KEYBOARD_INPUT_VIEW_MARGIN_HORIZONTAL                   8
#define RDR_KEYBOARD_INPUT_VIEW_MARGIN_BUTTONS_VERTICAL             7

@interface RDRKeyboardInputView () {
    UITextView *_textView;
    UIButton *_leftButton;
    UIButton *_rightButton;
}

@property (nonatomic, strong, readonly) UIToolbar *toolbar;

@end

@implementation RDRKeyboardInputView

#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame
{
    // Input view sets its own height
    if (self = [super initWithFrame:frame])
    {
        [self _setupSubviews];
    }
    
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder])
    {
        _textView = [decoder decodeObjectForKey:NSStringFromSelector(@selector(textView))];
        _leftButton = [decoder decodeObjectForKey:NSStringFromSelector(@selector(leftButton))];
        _rightButton = [decoder decodeObjectForKey:NSStringFromSelector(@selector(rightButton))];
        
        [self _setupSubviews];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.textView forKey:NSStringFromSelector(@selector(textView))];
    [coder encodeObject:self.leftButton forKey:NSStringFromSelector(@selector(leftButton))];
    [coder encodeObject:self.rightButton forKey:NSStringFromSelector(@selector(rightButton))];
}

#pragma mark - Getters

- (UITextView *)textView
{
    if (_textView != nil) {
        return _textView;
    }
    
    _textView = [UITextView new];
    self.textView.font = [UIFont systemFontOfSize:15.0f];
    self.textView.layer.cornerRadius = 5.0f;
    self.textView.layer.borderWidth = 1.0f;
    self.textView.layer.borderColor =  [UIColor colorWithRed:200.0f/255.0f
                                                       green:200.0f/255.0f
                                                        blue:205.0f/255.0f
                                                       alpha:1.0f].CGColor;
    
    return self.textView;
}

- (UIButton *)leftButton
{
    if (_leftButton != nil) {
        return _leftButton;
    }
    
    _leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _leftButton.titleLabel.font = [UIFont systemFontOfSize:15.0f];
    
    [_leftButton setTitle:NSLocalizedString(@"Other", nil)
                 forState:UIControlStateNormal];
    
    return _leftButton;
}

- (UIButton *)rightButton
{
    if (_rightButton != nil) {
        return _rightButton;
    }
    
    _rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _rightButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    
    [_rightButton setTitle:NSLocalizedString(@"Send", nil)
                  forState:UIControlStateNormal];
    
    return _rightButton;
}

#pragma mark - Public

- (instancetype)copy
{
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    RDRKeyboardInputView *inputViewKeyboard = (RDRKeyboardInputView *)
    [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    
    inputViewKeyboard.textView.layer.cornerRadius = self.textView.layer.cornerRadius;
    inputViewKeyboard.textView.layer.borderWidth = self.textView.layer.borderWidth;
    inputViewKeyboard.textView.layer.borderColor = self.textView.layer.borderColor;

    return inputViewKeyboard;
}

#pragma mark - Private

- (void)_setupSubviews
{
    _toolbar = [UIToolbar new];
    _toolbar.translucent = YES;
    [self addSubview:self.toolbar];
    
    [self addSubview:self.leftButton];
    [self addSubview:self.rightButton];
    [self addSubview:self.textView];
    
    [self _setupConstraints];
}

- (void)_setupConstraints
{
    // Calculate frame with current settings
    CGFloat height = 33.895000 + (2 * RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL);
    height = roundf(height);
    
    CGRect newFrame = self.frame;
    newFrame.size.height = height;
    self.frame = newFrame;
        
    // Calculate button margin with new frame height
    [self.leftButton sizeToFit];
    [self.rightButton sizeToFit];
    
    CGFloat leftButtonMargin =
    roundf((height - self.leftButton.frame.size.height) / 2.0f);
    CGFloat rightButtonMargin =
    roundf((height - self.rightButton.frame.size.height) / 2.0f);
    
    leftButtonMargin = roundf(leftButtonMargin);
    rightButtonMargin = roundf(rightButtonMargin);
    
    // Set autolayout property
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.leftButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.rightButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Define constraints
    NSArray *constraints = nil;
    NSString *visualFormat = nil;
    NSDictionary *views = @{ @"leftButton" : self.leftButton,
                             @"rightButton" : self.rightButton,
                             @"textView" : self.textView,
                             @"toolbar" : self.toolbar};
    NSDictionary *metrics = @{ @"hor" : @(RDR_KEYBOARD_INPUT_VIEW_MARGIN_HORIZONTAL),
                               @"ver" : @(RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL),
                               @"leftButtonMargin" : @(leftButtonMargin),
                               @"rightButtonMargin" : @(rightButtonMargin)};
    
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[toolbar]|"
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[toolbar]|"
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    visualFormat = @"H:|-(==hor)-[leftButton]-(==hor)-[textView]-(==hor)-[rightButton]-(==hor)-|";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    visualFormat = @"V:|-(>=leftButtonMargin)-[leftButton]-(==leftButtonMargin)-|";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    visualFormat = @"V:|-(>=rightButtonMargin)-[rightButton]-(==rightButtonMargin)-|";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    visualFormat = @"V:|-(==ver)-[textView]-(==ver)-|";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
}

@end

#pragma mark - UIScrollView + RDRStickyKeyboardView

#define RDR_SCROLL_ANIMATION_DURATION                   0.25f

@implementation UIScrollView (RDRStickyKeyboardView)

#pragma mark - Public

- (BOOL)rdr_isAtBottom
{
    UIScrollView *scrollView = self;
    CGFloat y = scrollView.contentOffset.y;
    CGFloat yBottom = RDRContentOffsetForBottom(scrollView);
    
    return (y == yBottom);
}

- (void)rdr_scrollToBottomAnimated:(BOOL)animated
               withCompletionBlock:(void(^)(void))completionBlock
{
    [self rdr_scrollToBottomWithOptions:0
                               duration:RDR_SCROLL_ANIMATION_DURATION
                        completionBlock:completionBlock];
}

- (void)rdr_scrollToBottomWithOptions:(UIViewAnimationOptions)options
                             duration:(CGFloat)duration
                      completionBlock:(void(^)(void))completionBlock
{
    UIScrollView *scrollView = self;
    CGPoint contentOffset = scrollView.contentOffset;
    contentOffset.y = RDRContentOffsetForBottom(scrollView);
    
    void(^animations)() = ^{
        scrollView.contentOffset = contentOffset;
    };
    
    void(^completion)(BOOL) = ^(BOOL finished){
        if (completionBlock) {
            completionBlock();
        }
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:options
                     animations:animations
                     completion:completion];
}

@end

#pragma mark - RDRStickyKeyboardView

static NSInteger const RDRInterfaceOrientationUnknown   = -1;

@interface RDRStickyKeyboardView () {
    UIInterfaceOrientation _currentOrientation;
    RDRKeyboardInputView *_inputViewKeyboard;
    RDRKeyboardInputView *_inputViewScrollView;
}

@property (nonatomic, strong, readonly) RDRKeyboardInputView *inputViewKeyboard;

@end

@implementation RDRStickyKeyboardView

#pragma mark - Lifecycle

- (instancetype)initWithScrollView:(UIScrollView *)scrollView
{
    if (self = [super init])
    {
        _scrollView = scrollView;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|
        UIViewAutoresizingFlexibleHeight;
        _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        
        _currentOrientation = RDRInterfaceOrientationUnknown;
        
        [self _setupSubviews];
        [self _registerForNotifications];
    }
    
    return self;
}

- (void)dealloc
{
    [self _unregisterForNotifications];
}

#pragma mark - Getters

- (RDRKeyboardInputView *)inputViewKeyboard
{
    if (!_inputViewKeyboard) {
        _inputViewKeyboard = [self.inputViewScrollView copy];
    }
    
    return _inputViewKeyboard;
}

- (RDRKeyboardInputView *)inputViewScrollView
{
    if (!_inputViewScrollView) {
        _inputViewScrollView = [RDRKeyboardInputView new];
    }
    
    return _inputViewScrollView;
}

- (RDRKeyboardInputView *)inputView
{
    return self.inputViewKeyboard;
}

#pragma mark - Overrides

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview == nil) {
        [super willMoveToSuperview:newSuperview];
        return;
    }
    
    [self _setInitialFrames];
    [super willMoveToSuperview:newSuperview];
}

#pragma mark - Public

- (void)showKeyboard
{
    [self.inputViewScrollView.textView becomeFirstResponder];
}

- (void)hideKeyboard
{
    [self.inputViewKeyboard.textView resignFirstResponder];
    [self.inputViewScrollView.textView resignFirstResponder];
}

#pragma mark - Private

- (void)_setupSubviews
{
    // Add scrollview as subview
    [self addSubview:self.scrollView];
    
    // Setup the view where the user will actually
    // be typing in
    self.inputViewScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|
    UIViewAutoresizingFlexibleTopMargin;
    [self addSubview:self.inputViewScrollView];
    
    CGRect frame = CGRectZero;
    frame.size = self.inputViewScrollView.frame.size;
    self.inputViewKeyboard.frame = frame;
    
    self.inputViewScrollView.textView.inputAccessoryView = self.inputViewKeyboard;
    self.inputViewKeyboard.autoresizingMask = UIViewAutoresizingFlexibleWidth|
    UIViewAutoresizingFlexibleHeight;
    
}

- (void)_setInitialFrames
{
    CGRect dummyInputViewFrame = self.inputViewScrollView.frame;
    dummyInputViewFrame.size.width = self.frame.size.width;
    dummyInputViewFrame.origin.y = self.frame.size.height - dummyInputViewFrame.size.height;
    self.inputViewScrollView.frame = dummyInputViewFrame;
    
    CGRect scrollViewFrame = CGRectZero;
    scrollViewFrame.size.width = self.frame.size.width;
    scrollViewFrame.size.height = self.frame.size.height - self.inputViewScrollView.frame.size.height;
    self.scrollView.frame = scrollViewFrame;
}

#pragma mark - Notifications

- (void)_registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_textViewDidEndEditing:)
                                                 name:UITextViewTextDidEndEditingNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_textViewDidChange:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:nil];
}

- (void)_unregisterForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillChangeFrameNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidEndEditingNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextViewTextDidChangeNotification
                                                  object:nil];
}

#pragma mark - Notification handlers
#pragma mark - Keyboard

- (void)_keyboardWillShow:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect beginFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    // Check if orientation changed
    [self _updateInputViewFrameIfOrientationChanged:endFrame];
    
    CGRect inputViewBounds = self.inputViewKeyboard.bounds;
    if (RDRKeyboardSizeEqualsInputViewSize(endFrame, inputViewBounds)) {
        return; // escape when the input view is at the bottom of window
    }
    
    [self.inputViewKeyboard.textView becomeFirstResponder];
  
    if (RDRKeyboardSizeEqualsInputViewSize(beginFrame, inputViewBounds)) {
        return;
    }
    
    // New and old keyboard origin should differ exactly
    // one keyboard height
    if (!RDRKeyboardFrameChangeEqualsKeyboardHeight(beginFrame, endFrame)) {
        return;
    }
    
    // Make sure the keyboard is actually shown
    if (!RDRKeyboardIsFullyShown(endFrame)) {
        return;
    }
    
    // Make sure the keyboard was not already shown
    if (RDRKeyboardIsFullyShown(beginFrame)) {
        return;
    }
    
    [self _scrollViewAdaptInsetsToKeyboardFrame:endFrame];
    [self.scrollView rdr_scrollToBottomWithOptions:RDRAnimationOptionsForCurve(curve)
                                          duration:duration
                                   completionBlock:nil];
}

- (void)_keyboardWillChangeFrame:(NSNotification *)notification
{
    // This method is called many times on different occasions.
    
    // This method is called when the user has stopped dragging
    // the keyboard and it is about to animate downwards.
    // The keyboardWillHide method determines if that is the case
    // and adjusts the interface accordingly.
    [self _keyboardWillHide:notification];
    
    // This method is called when the user has switched
    // to a different keyboard. The keyboardWillSwitch method
    // determines if that is the case and adjusts the interface
    // accordingly.
    [self _keyboardWillSwitch:notification];
}

- (void)_keyboardWillHide:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect beginFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    // When the user has lifted his or her finger, the
    // size of the end frame equals the size of the input view.
    CGRect inputViewBounds = self.inputViewKeyboard.bounds;
    if (!RDRKeyboardSizeEqualsInputViewSize(endFrame, inputViewBounds)) {
        // Check if keyboard might have been dismissed programmatically
        if (!RDRKeyboardFrameChangeEqualsKeyboardHeight(beginFrame, endFrame)) {
            return;
        }
        if (!RDRKeyboardIsFullyShown(beginFrame)) {
            return;
        }
    }
    
    // Workaround for change in iOS 7.1: a frame change
    // notification is posted when the keyboard itself has
    // already disappeared and the input view is at the
    // bottom of the screen and about to follow the keyboard
    // into disappearance.
    // We hook into this notification and hide the input
    // view, so we do not see the input view traverse downwards
    // while overlapping the dummy input view (fixes issue #3).
    if (RDRKeyboardFrameChangeEqualsInputViewHeight(beginFrame,
                                                    endFrame,
                                                    inputViewBounds)){
        self.inputViewKeyboard.alpha = 0.0f;
    }
    
    // Construct the frame that should actually have been
    // passed into the userinfo dictionary and use it
    // internally.
    // The subsequently called methods expect window
    // coordinates. Construct the frame, convert it to
    // window coordinates when done.
    UIView *view = self.window.rootViewController.view;
    CGRect beginFrameConverted = [view convertRect:beginFrame
                                          fromView:nil];
    
    CGRect viewRect = CGRectZero;
    viewRect.origin.y = view.bounds.size.height;
    viewRect.size = beginFrameConverted.size;
    
    CGRect windowRect = [self.window convertRect:viewRect fromView:view];
    [self _scrollViewAdaptInsetsToKeyboardFrame:windowRect];
    [self.scrollView rdr_scrollToBottomWithOptions:RDRAnimationOptionsForCurve(curve)
                                          duration:duration
                                   completionBlock:nil];
    
    if ([self.inputViewKeyboard.textView isFirstResponder]) {
        [self.inputViewKeyboard.textView resignFirstResponder];
    }

}

#pragma mark - UITextView

- (void)_textViewDidEndEditing:(NSNotification *)notification
{
    UITextView *textView = notification.object;
    
    if (textView == self.inputViewKeyboard.textView) {
        // Synchronize text between actual input view and
        // dummy input view.
        self.inputViewScrollView.textView.text = textView.text;
    }
}

- (void)_textViewDidChange:(NSNotification *)notification
{
    [self _updateInputViewFrameWithKeyboardFrame:CGRectZero
                                     forceReload:NO];
}

#pragma mark - Notification handler helpers

- (void)_keyboardWillSwitch:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect beginFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    // Disregard false notification
    // This works around a bug in iOS
    CGRect inputViewBounds = self.inputViewKeyboard.bounds;
    if (RDRKeyboardSizeEqualsInputViewSize(endFrame, inputViewBounds)) {
        return;
    }
    
    if (RDRKeyboardSizeEqualsInputViewSize(beginFrame, inputViewBounds)) {
        return;
    }
    
    // Disregard when old and new keyboard origin differ
    // exactly one keyboard height
    if (RDRKeyboardFrameChangeEqualsKeyboardHeight(beginFrame, endFrame)) {
        return;
    }
    
    // Make sure keyboard is fully shown
    if (RDRKeyboardIsFullyHidden(endFrame)) {
        return;
    }
    
    // Only handle the case when the keyboard is already visible
    // and the user changes to a different keyboard that has a
    // different height.
    
    [self _scrollViewAdaptInsetsToKeyboardFrame:endFrame];
    [self.scrollView rdr_scrollToBottomWithOptions:RDRAnimationOptionsForCurve(curve)
                                          duration:duration
                                   completionBlock:nil];
}

#pragma mark - Scrollview

- (void)_scrollViewAdaptInsetsToKeyboardFrame:(CGRect)keyboardFrame
{
    // Convert keyboard frame to view coordinates
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIView *view = window.rootViewController.view;
    CGRect convertedRect = [view convertRect:keyboardFrame
                                    fromView:nil];
    
    CGFloat keyboardHeight = convertedRect.size.height;
    CGFloat inputViewHeight = self.inputViewKeyboard.bounds.size.height;
    
    // If the keyboard is hidden, set bottom inset to zero.
    // If the keyboard is not hidden, set the content inset's bottom
    // to the height of the area occupied by the keyboard itself.
    CGFloat bottomInset = keyboardHeight - inputViewHeight;
    bottomInset *= RDRKeyboardIsFullyHidden(keyboardFrame) ? 0 : 1;
    
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.bottom = bottomInset;
    self.scrollView.contentInset = contentInset;
    
    UIEdgeInsets scrollIndicatorInsets = self.scrollView.scrollIndicatorInsets;
    scrollIndicatorInsets.bottom = bottomInset;
    self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets;
}

#pragma mark - Input view

- (void)_updateInputViewFrameIfOrientationChanged:(CGRect)keyboardFrame
{
    // Check if orientation changed
    UIApplication *application = [UIApplication sharedApplication];
    UIInterfaceOrientation orientation = application.statusBarOrientation;
    
    if (_currentOrientation != RDRInterfaceOrientationUnknown &&
        _currentOrientation != orientation) {
        [self _updateInputViewFrameWithKeyboardFrame:keyboardFrame
                                         forceReload:YES];
    }
    
    _currentOrientation = orientation;
}

- (void)_updateInputViewFrameWithKeyboardFrame:(CGRect)keyboardFrame
                                   forceReload:(BOOL)reload
{
    // If the keyboardFrame equals CGRectZero and
    // the inputViewKeyboard is not visible yet, we won't be able
    // to access the keyboard's frame.
#ifdef DEBUG
    NSCAssert(!(CGRectEqualToRect(keyboardFrame, CGRectZero) &&
                self.inputViewKeyboard.superview == nil), nil);
#endif
    
    // Check if we can manually grab the keyboard's frame.
    // If not, use the keyboardFrame parameter.
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *view = window.rootViewController.view;
    CGRect windowKeyboardFrame = keyboardFrame;
    
    if (self.inputViewKeyboard.superview != nil) {
        windowKeyboardFrame = [window convertRect:self.inputViewKeyboard.superview.frame
                                         fromView:self.inputViewKeyboard.superview.superview];
    }
    
    // Convert keyboard frame to view coordinates
    CGRect viewKeyboardFrame = [view convertRect:windowKeyboardFrame
                                        fromView:nil];
    
    // Calculate max input view height
    CGFloat maxInputViewHeight = viewKeyboardFrame.origin.y -
    self.frame.origin.y - self.scrollView.contentInset.top;
    maxInputViewHeight += self.inputViewKeyboard.bounds.size.height;
    
    // Calculate the height the input view ideally
    // has based on its textview's content
    UITextView *textView = self.inputViewKeyboard.textView;
    CGFloat newInputViewHeight = RDRTextViewHeight(textView);
    newInputViewHeight += (2 * RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL);
    newInputViewHeight = ceilf(newInputViewHeight);
    newInputViewHeight = MIN(maxInputViewHeight, newInputViewHeight);
    
    // If the new input view height equals the current,
    // nothing has to be changed
    if (self.inputViewKeyboard.bounds.size.height == newInputViewHeight) {
        return;
    }
    
    // Propagate the height change
    // Update the scrollview's frame
    CGRect scrollViewFrame = self.scrollView.frame;
    scrollViewFrame.size.height = self.frame.size.height - newInputViewHeight;
    self.scrollView.frame = scrollViewFrame;
    
    // The new input view height is different from the current.
    // Update the dummy input view's frame
    CGRect dummyInputViewFrame = self.inputViewScrollView.frame;
    dummyInputViewFrame.size.height = newInputViewHeight;
    dummyInputViewFrame.origin.y = self.frame.size.height - newInputViewHeight;
    self.inputViewScrollView.frame = dummyInputViewFrame;
    
    // Update the actual input view's height
    // This will cause the keyboardWillChange notification to be fired.
    // The handler of the keyboardWillChange notification will
    // subsequently take care of resizing the scrollview and
    // its content, so we don't have to do that here.
    CGRect inputViewFrame = self.inputViewKeyboard.frame;
    inputViewFrame.size.height = newInputViewHeight;
    self.inputViewKeyboard.frame = inputViewFrame;
    
    // If the changes should be propagated with force,
    // call reloadInputViews on the dummy text view.
    // reloadInputViews will only have effect if the
    // callee is the current first responder.
    if (reload) {
        [self.inputViewScrollView.textView becomeFirstResponder];
        [self.inputViewScrollView.textView reloadInputViews];
        [self.inputViewKeyboard.textView becomeFirstResponder];
    }
}

@end
