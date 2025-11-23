//
//  AppDelegate.m
//  BezierKit
//
//  Created by Joseph Smithberger on 11/21/25.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Configure the window
    [self.window setTitle:@"BezierKit"];
    [self.window setContentSize:NSMakeSize(400, 200)];
    
    NSView *contentView = self.window.contentView;
    [contentView setSubviews:@[]]; // Clear existing subviews
    
    // "Thanks for downloading BezierKit." Label
    NSTextField *thanksLabel = [NSTextField labelWithString:@"Thanks for downloading BezierKit."];
    [thanksLabel setFont:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium]];
    [thanksLabel setAlignment:NSTextAlignmentCenter];
    [thanksLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:thanksLabel];
    
    // "Created by Joseph Smithberger." Label
    NSTextField *authorLabel = [NSTextField labelWithString:@"Created by Joseph Smithberger."];
    [authorLabel setFont:[NSFont systemFontOfSize:13]];
    [authorLabel setTextColor:[NSColor secondaryLabelColor]];
    [authorLabel setAlignment:NSTextAlignmentCenter];
    [authorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:authorLabel];
    
    // Website Link
    NSTextField *linkLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [linkLabel setBezeled:NO];
    [linkLabel setDrawsBackground:NO];
    [linkLabel setEditable:NO];
    [linkLabel setSelectable:YES];
    [linkLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSString *linkText = @"https://josephsmithberger.com";
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:linkText];
    NSRange range = NSMakeRange(0, [linkText length]);
    [attrString addAttribute:NSLinkAttributeName value:linkText range:range];
    [attrString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13] range:range];
    [linkLabel setAttributedStringValue:attrString];
    
    [contentView addSubview:linkLabel];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [thanksLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [thanksLabel.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor constant:-20],
        
        [authorLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [authorLabel.topAnchor constraintEqualToAnchor:thanksLabel.bottomAnchor constant:8],
        
        [linkLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [linkLabel.topAnchor constraintEqualToAnchor:authorLabel.bottomAnchor constant:8]
    ]];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
