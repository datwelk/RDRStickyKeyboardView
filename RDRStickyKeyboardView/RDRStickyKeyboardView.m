//
//  RDRStickyKeyboardView.m
//
//  Created by Damiaan Twelker on 17/01/14.
//  Copyright (c) 2014 Damiaan Twelker. All rights reserved.
//
// LICENSE
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "RDRStickyKeyboardView.h"

#pragma mark - Convenience methods

static BOOL RDRInterfaceOrientationIsPortrait(UIInterfaceOrientation orientation) {
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            return YES;
            break;
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return NO;
            break;
    }
}

static BOOL RDRCurrentStatusBarOrientationIsPortrait() {
    UIApplication *application = [UIApplication sharedApplication];
    UIInterfaceOrientation orientation = application.statusBarOrientation;
    return RDRInterfaceOrientationIsPortrait(orientation);
}

static BOOL RDRKeyboardSizeEqualsInputViewSize(CGSize keyboardSize,
                                               CGSize inputViewSize) {
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    CGSize flippedInputViewSize = CGSizeZero;
    flippedInputViewSize.width = inputViewSize.height;
    flippedInputViewSize.height = inputViewSize.width;
    
    if (CGSizeEqualToSize(keyboardSize, inputViewSize) && portrait) {
        return YES;
    }
    
    if (CGSizeEqualToSize(keyboardSize, flippedInputViewSize) && !portrait) {
        return YES;
    }
    
    return NO;
}

static BOOL RDRKeyboardFrameChangeIsShowHideAnimation(CGRect beginFrame,
                                                      CGRect endFrame) {
    // New and old keyboard origin should differ exactly
    // one keyboard height
    
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    CGFloat yDiff = endFrame.origin.y - beginFrame.origin.y;
    CGFloat xDiff = endFrame.origin.x - beginFrame.origin.x;
    
    yDiff = fabs(yDiff);
    xDiff = fabs(xDiff);
    
    if (portrait) {
        if (yDiff != endFrame.size.height) {
            return NO;
        }
    }
    else {
        if (xDiff != endFrame.size.width) {
            return NO;
        }
    }
    
    return YES;
}

static BOOL RDRKeyboardIsFullyShown(CGRect keyboardFrame) {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    CGFloat heightDiff = keyWindow.frame.size.height - keyboardFrame.size.height;
    CGFloat widthDiff = keyWindow.frame.size.width - keyboardFrame.size.width;
    
    if (portrait) {
        if (heightDiff != keyboardFrame.origin.y) {
            return NO;
        }
    }
    else {
        if (widthDiff != keyboardFrame.origin.x) {
            return NO;
        }
    }
    
    return YES;
}

static BOOL RDRKeyboardIsFullyHidden(CGRect keyboardFrame) {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    if (portrait) {
        if (keyWindow.frame.size.height != keyboardFrame.origin.y) {
            return NO;
        }
    }
    else {
        if (keyWindow.frame.size.width != keyboardFrame.origin.x) {
            return NO;
        }
    }
    
    return YES;
}

static inline CGFloat RDRTextViewHeight(UITextView *textView) {
    NSTextContainer *textContainer = textView.textContainer;
    CGRect textRect =
    [textView.layoutManager usedRectForTextContainer:textContainer];
    
    CGFloat textViewHeight = textRect.size.height +
    textView.textContainerInset.top + textView.textContainerInset.bottom;
    
    return textViewHeight;
}

static inline UIViewAnimationOptions RDRAnimationOptionsForCurve(UIViewAnimationCurve curve) {
    return (curve << 16 | UIViewAnimationOptionBeginFromCurrentState);
}

#pragma mark - RDRKeyboardInputView

#define RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL                     5
#define RDR_KEYBOARD_INPUT_VIEW_MARGIN_HORIZONTAL                   8

@interface RDRKeyboardInputView ()

@property (nonatomic, strong, readonly) UIToolbar *toolbar;

@end

@implementation RDRKeyboardInputView

#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self _setupSubviews];
    }
    
    return self;
}

#pragma mark - Private

- (void)_setupSubviews
{
    // Add toolbar to bg, but dont use it
    _toolbar = [UIToolbar new];
    [self addSubview:self.toolbar];
    
    // Add custom views
    _leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.leftButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    [self.leftButton setTitle:NSLocalizedString(@"Other", nil)
                     forState:UIControlStateNormal];
    [self addSubview:self.leftButton];
    
    _rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.rightButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    [self.rightButton setTitle:NSLocalizedString(@"Send", nil)
                      forState:UIControlStateNormal];
    [self addSubview:self.rightButton];
    
    _textView = [UITextView new];
    self.textView.font = [UIFont systemFontOfSize:15.0f];
    self.textView.layer.cornerRadius = 5.0f;
    self.textView.layer.borderWidth = 1.0f;
    self.textView.layer.borderColor = [UIColor colorWithRed:200.0f/255.0f
                                                      green:200.0f/255.0f
                                                       blue:205.0f/255.0f
                                                      alpha:1.0f].CGColor;
    [self addSubview:self.textView];
    
    [self _setupConstraints];
}

- (void)_setupConstraints
{
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.leftButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.rightButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *constraints = nil;
    NSString *visualFormat = nil;
    NSDictionary *views = @{ @"leftButton" : self.leftButton,
                             @"rightButton" : self.rightButton,
                             @"textView" : self.textView,
                             @"toolbar" : self.toolbar};
    NSDictionary *metrics = @{ @"hor" : @(RDR_KEYBOARD_INPUT_VIEW_MARGIN_HORIZONTAL),
                               @"ver" : @(RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL)};
    
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
    
    visualFormat = @"V:[leftButton]-(==ver)-|";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:views];
    [self addConstraints:constraints];
    
    visualFormat = @"V:[rightButton]-(==ver)-|";
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

#pragma mark - RDRStickyKeyboardView

#define RDR_KEYBOARD_INPUT_VIEW_HEIGHT              44.0f

@interface RDRStickyKeyboardView () <UITextViewDelegate> {
    CGRect _currentKeyboardFrame;
    UIDeviceOrientation _lastOrientation;
}

@property (nonatomic, strong) RDRKeyboardInputView *dummyInputView;

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
        
        [self _setupSubviews];
        [self _registerForNotifications];
    }
    
    return self;
}

- (void)dealloc
{
    [self _unregisterForNotifications];
}

#pragma mark - Overrides

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview == nil) {
        return;
    }
    
    [self _setInitialFrames];
    [super willMoveToSuperview:newSuperview];
}

#pragma mark - Private

- (void)_setupSubviews
{
    // Add scrollview as subview
    [self addSubview:self.scrollView];
    
    // Setup the view where the user will actually
    // be typing in
    _inputView = [RDRKeyboardInputView new];
    self.inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.inputView.textView.delegate = self;
    
    // Setup a dummy input view that appears on the bottom
    // of this view, right below the scrollview. The user will
    // tap the dummy view, whose textview's inputAccessoryView is
    // the actual input view. The actual input view will be made
    // first responder as soon as the dummy view's textview
    // has become first responder.
    self.dummyInputView = [RDRKeyboardInputView new];
    self.dummyInputView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
    self.dummyInputView.textView.inputAccessoryView = self.inputView;
    self.dummyInputView.textView.tintColor = [UIColor clearColor]; // hide cursor
    self.dummyInputView.textView.delegate = self;
    [self addSubview:self.dummyInputView];
}

- (void)_setInitialFrames
{
    CGRect scrollViewFrame = CGRectZero;
    scrollViewFrame.size.width = self.frame.size.width;
    scrollViewFrame.size.height = self.frame.size.height - RDR_KEYBOARD_INPUT_VIEW_HEIGHT;
    self.scrollView.frame = scrollViewFrame;
    
    CGRect inputViewFrame = CGRectZero;
    inputViewFrame.size.width = self.frame.size.width;
    inputViewFrame.size.height = RDR_KEYBOARD_INPUT_VIEW_HEIGHT;
    self.inputView.frame = inputViewFrame;
    
    CGRect dummyInputViewFrame = CGRectZero;
    dummyInputViewFrame.origin.y = self.frame.size.height - inputViewFrame.size.height;
    dummyInputViewFrame.size = inputViewFrame.size;
    self.dummyInputView.frame = dummyInputViewFrame;
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
    
    [self _registerForDeviceOrientationNotification];
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
    
    [self _unregisterForDeviceOrientationNotification];
}

- (void)_registerForDeviceOrientationNotification
{
    _lastOrientation = [UIDevice currentDevice].orientation;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)_unregisterForDeviceOrientationNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

#pragma mark - Notification handlers
#pragma mark - Orientation

- (void)_deviceOrientationDidChange:(NSNotification *)notification
{
    if (!self.inputView.textView.isFirstResponder) {
        return;
    }
    
    UIDeviceOrientation newOrientation = [UIDevice currentDevice].orientation;
    
    if (_lastOrientation == newOrientation) {
        return;
    }
    if (_lastOrientation == UIDeviceOrientationUnknown) {
        _lastOrientation = newOrientation;
        return;
    }
    
    _lastOrientation = newOrientation;
    [self _updateInputViewTextViewFrameAndForceReload:YES];
}

#pragma mark - Keyboard

- (void)_keyboardWillShow:(NSNotification *)notification
{
    // This method is called because the user has tapped
    // the dummy input view, which has become first responder.
    // Take over first responder status from the dummy input view
    // and transfer it to the actual input view, which is the
    // inputAccessoryView of the dummy input view.
    [self.inputView.textView becomeFirstResponder];
    
    // If the keyboard is actually shown,
    // adapt the content animated
    NSDictionary *userInfo = notification.userInfo;
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect beginFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    // Disregard false notification
    // This works around a bug in iOS
    CGSize inputViewSize = self.inputView.frame.size;
    if (RDRKeyboardSizeEqualsInputViewSize(endFrame.size, inputViewSize)) {
        return;
    }
    
    if (RDRKeyboardSizeEqualsInputViewSize(beginFrame.size, inputViewSize)) {
        return;
    }
    
    // New and old keyboard origin should differ exactly
    // one keyboard height
    if (!RDRKeyboardFrameChangeIsShowHideAnimation(beginFrame, endFrame)) {
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
    
    
    [self _scrollViewAdaptInsetsToKeyboardFrame:endFrame];
    [self _scrollViewScrollToBottomWithKeyboardFrame:endFrame
                                               curve:curve
                                            duration:duration];
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
    
    // Save keyboard frame. The frame is used inside the
    // updateFrameForTextView method.
    NSDictionary *userInfo = notification.userInfo;
    _currentKeyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
}

- (void)_keyboardWillHide:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect beginFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    // When the user has lifted his or her finger, the
    // size of the end frame equals the size of the input view.
    CGSize inputViewSize = self.inputView.frame.size;
    if (!RDRKeyboardSizeEqualsInputViewSize(endFrame.size, inputViewSize)) {
        return;
    }
    
    // Construct the frame that should actually have been
    // passed into the userinfo dictionary and use it
    // internally.
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    CGSize windowSize = keyWindow.frame.size;
    
    CGRect newEndFrame = CGRectZero;
    newEndFrame.origin.y = portrait ? windowSize.height : windowSize.width;
    newEndFrame.size = beginFrame.size;
    
    [self _scrollViewAdaptInsetsToKeyboardFrame:newEndFrame];
    [self _scrollViewScrollToBottomWithKeyboardFrame:newEndFrame
                                               curve:curve
                                            duration:duration];
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
    CGSize inputViewSize = self.inputView.frame.size;
    if (RDRKeyboardSizeEqualsInputViewSize(endFrame.size, inputViewSize)) {
        return;
    }
    
    if (RDRKeyboardSizeEqualsInputViewSize(beginFrame.size, inputViewSize)) {
        return;
    }
    
    // Disregard when old and new keyboard origin differ
    // exactly one keyboard height
    if (RDRKeyboardFrameChangeIsShowHideAnimation(beginFrame, endFrame)) {
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
    [self _scrollViewScrollToBottomWithKeyboardFrame:endFrame
                                               curve:curve
                                            duration:duration];
}

- (void)_scrollViewAdaptInsetsToKeyboardFrame:(CGRect)keyboardFrame
{
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    CGFloat keyboardHeight = keyboardFrame.size.height;
    CGFloat keyboardWidth = keyboardFrame.size.width;
    CGFloat inputViewHeight = self.inputView.frame.size.height;
   
    // If the keyboard is hidden, set bottom inset to zero.
    // If the keyboard is not hidden, set the content inset's bottom
    // to the height of the area occupied by the keyboard itself.
    CGFloat bottomInset = portrait ? keyboardHeight : keyboardWidth;
    bottomInset -= inputViewHeight;
    bottomInset *= RDRKeyboardIsFullyHidden(keyboardFrame) ? 0 : 1;
    
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.bottom = bottomInset;
    self.scrollView.contentInset = contentInset;
    
    UIEdgeInsets scrollIndicatorInsets = self.scrollView.scrollIndicatorInsets;
    scrollIndicatorInsets.bottom = bottomInset;
    self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets;
}

- (void)_scrollViewScrollToBottomWithKeyboardFrame:(CGRect)keyboardFrame
                                             curve:(UIViewAnimationCurve)curve
                                          duration:(CGFloat)duration
{
    CGFloat contentHeight = self.scrollView.contentSize.height;
    CGFloat scrollViewHeight = self.scrollView.bounds.size.height;
    CGFloat bottomInset = self.scrollView.contentInset.bottom;
    
    // To scroll a scrollview to the bottom, one would
    // set the content offset y coordinate to the content height
    // minus the height of the scrollview. When the keyboard is
    // visible, however, the actually visible height of the
    // scrollview is less - the difference exactly equals the
    // bottom inset, which has been set through the method
    // _scrollViewAdaptInsetsToKeyboardFrame:.
    CGPoint contentOffset = self.scrollView.contentOffset;
    contentOffset.y = contentHeight - (scrollViewHeight - bottomInset);
    
    // Animate scroll
    void(^animations)() = ^{
        self.scrollView.contentOffset = contentOffset;
    };
    
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:RDRAnimationOptionsForCurve(curve)
                     animations:animations
                     completion:nil];
}

#pragma mark - Textview delegate helpers

- (void)_updateInputViewTextViewFrameAndForceReload:(BOOL)reload
{
    BOOL portrait = RDRCurrentStatusBarOrientationIsPortrait();
    
    // Use the keyWindow to convert the frame.
    // The keyWindow should be the window with the keyboard
    // on it (UITextEffectsWindow)
    
    // Add the top of the scrollview's top content inset,
    // since on iOS 7 all views inside viewcontrollers are
    // positioned underneath the navigation bar.
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CGRect convertedFrame = [window convertRect:self.frame
                                       fromView:self.superview];
    convertedFrame.origin.y += portrait ? self.scrollView.contentInset.top : 0;
    convertedFrame.origin.x += portrait ? 0 : self.scrollView.contentInset.top;
    
    // Calculate the tallest height the input view could
    // possibly have
    CGFloat maxInputViewHeight = portrait ?
    (_currentKeyboardFrame.origin.y - convertedFrame.origin.y) :
    (_currentKeyboardFrame.origin.x - convertedFrame.origin.x);
    maxInputViewHeight += self.inputView.frame.size.height;
    
    // Calculate the height the input view wants to have
    // based on its textview's content
    UITextView *textView = self.inputView.textView;
    CGFloat newInputViewHeight = RDRTextViewHeight(textView);
    newInputViewHeight += (2 * RDR_KEYBOARD_INPUT_VIEW_MARGIN_VERTICAL);
    newInputViewHeight = ceilf(newInputViewHeight);
    newInputViewHeight = MIN(maxInputViewHeight, newInputViewHeight);
    
    
    // If the new height equals the current height, nothing
    // has to be changed
    if (self.inputView.frame.size.height == newInputViewHeight) {
        return;
    }
    
    // Update the scrollview's frame
    CGRect scrollViewFrame = self.scrollView.frame;
    scrollViewFrame.size.height = self.frame.size.height - newInputViewHeight;
    self.scrollView.frame = scrollViewFrame;
    
    // The new input view height is different from the current.
    // Update the dummy input view's frame
    CGRect dummyInputViewFrame = self.dummyInputView.frame;
    dummyInputViewFrame.size.height = newInputViewHeight;
    dummyInputViewFrame.origin.y = self.frame.size.height - newInputViewHeight;
    self.dummyInputView.frame = dummyInputViewFrame;
    
    // Update the actual input view's height
    // This will cause the keyboardWillChange notification to be fired.
    // The handler of the keyboardWillChange notification will
    // subsequently take care of resizing the scrollview and
    // its content, so we don't have to do that here.
    CGRect inputViewFrame = self.inputView.frame;
    inputViewFrame.size.height = newInputViewHeight;
    self.inputView.frame = inputViewFrame;
    
    // If the changes should be propagated with force,
    // call reloadInputViews on the dummy text view.
    // reloadInputViews will only have effect if the
    // callee is the current first responder.
    if (reload) {
        [self.dummyInputView.textView becomeFirstResponder];
        [self.dummyInputView.textView reloadInputViews];
        [self.inputView.textView becomeFirstResponder];
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    if (textView != self.inputView.textView) {
        return YES;
    }
    
    // Synchronize text between actual input view and
    // dummy input view.
    self.dummyInputView.textView.text = textView.text;
    
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self _updateInputViewTextViewFrameAndForceReload:NO];
}

@end
