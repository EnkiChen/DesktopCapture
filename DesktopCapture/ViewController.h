//
//  ViewController.h
//  DesktopCapture
//
//  Created by Enki on 2018/10/17.
//  Copyright © 2018年 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSPopUpButton *dispalyPopUpButton;
@property (weak) IBOutlet NSPopUpButton *capturePopUpButton;
@property (weak) IBOutlet NSTextField *fpsTextField;
@property (weak) IBOutlet NSButton *btn;
@property (weak) IBOutlet NSTextField *sizeTextField;
@property (weak) IBOutlet NSButton *retinaCheckBox;
@property (weak) IBOutlet NSButton *exclusionCheckBox;
@property (assign) BOOL isCancel;

@end

