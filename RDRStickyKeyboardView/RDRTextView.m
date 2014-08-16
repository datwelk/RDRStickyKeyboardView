//
//  RDRTextView.m
//
//  Created by Ignacio Romero Zurbuchen on 15/08/14.
//  Copyright (c) 2014 Tiny Speck Inc. All rights reserved.
//
//  LICENSE
//  The MIT License (MIT)
//

#import "RDRTextView.h"

@interface RDRTextView ()

@property (nonatomic, strong) UILabel *placeholderLabel;

@end

@implementation RDRTextView

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self _setupSubviews];
        [self _beginObservingKeyboardNotifications];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self _beginObservingKeyboardNotifications];
    }
    
    return self;
}

- (void)dealloc
{
    [self _stopObservingKeyboardNotifications];
}

#pragma mark - Setup

- (void)_setupSubviews
{
    self.placeholderColor = [UIColor lightGrayColor];
    self.font = [UIFont systemFontOfSize:14.0];
}

- (void)_beginObservingKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_textViewDidChange:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:nil];
}

- (void)_stopObservingKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Getters

- (UILabel *)placeholderLabel
{
    if (!_placeholder) {
        return nil;
    }
    
    if (!_placeholderLabel) {
        _placeholderLabel = [UILabel new];
        _placeholderLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _placeholderLabel.numberOfLines = 0;
        _placeholderLabel.font = self.font;
        _placeholderLabel.backgroundColor = [UIColor clearColor];
        _placeholderLabel.textColor = _placeholderColor;
        _placeholderLabel.hidden = YES;
        
        [self addSubview:_placeholderLabel];
    }
    
    return _placeholderLabel;
}


#pragma mark - Setters

- (void)setText:(NSString *)text
{
    [super setText:text];
    [self _textViewDidChange:nil];
}

- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    self.placeholderLabel.font = self.font;
}

- (void)setPlaceholder:(NSString *)placeholder
{
    if ([placeholder isEqualToString:_placeholder]) {
        return;
    }
    
    _placeholder = placeholder;
    self.placeholderLabel.text = placeholder;
}

#pragma mark - Notifications

- (void)_textViewDidChange:(NSNotification *)notification
{
    if (self.placeholder.length == 0) {
        return;
    }
    
    _placeholderLabel.hidden = (self.text.length > 0) ? YES : NO;
}

- (BOOL)shouldRenderPlaceholder
{
    if (_placeholderLabel.hidden && self.placeholder.length > 0 && self.text.length == 0) {
        return YES;
    }
    return NO;
}

#pragma mark - UIViewRendering

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if (!_placeholder) {
        return;
    }
    
    if ([self shouldRenderPlaceholder]) {
        CGRect frame = self.bounds;
        frame.origin.x += 5.0;
        _placeholderLabel.frame = frame;
        _placeholderLabel.textColor = _placeholderColor;
        _placeholderLabel.hidden = NO;
        
        [self sendSubviewToBack:_placeholderLabel];
    }
}

@end