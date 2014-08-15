//
//  RDRTextView.m
//
//  Created by Ignacio Romero Zurbuchen on 15/08/14.
//  Copyright (c) 2014 Tiny Speck Inc. All rights reserved.
//
//  LICENSE
//  The MIT License (MIT)
//

#import <UIKit/UIKit.h>

/** A custom text view with placeholder text. */
@interface RDRTextView : UITextView

/** The placeholder text string. */
@property (nonatomic, strong) NSString *placeholder;
/** The placeholder color. */
@property (nonatomic, strong) UIColor *placeholderColor;

@end
