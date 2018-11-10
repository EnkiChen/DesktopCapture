//
//  ViewController.m
//  DesktopCapture
//
//  Created by Enki on 2018/10/17.
//  Copyright © 2018年 Enki. All rights reserved.
//

#import "ViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#include <unistd.h>
#include <sys/time.h>
#include <vector>

#define millisecond(tv) ((int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000)

CFArrayRef CreateWindowListWithExclusion(std::vector<CGWindowID> windows_to_exclude) {
    if (windows_to_exclude.empty())
        return nullptr;
    
    CFArrayRef all_windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (!all_windows)
        return nullptr;
    
    CFMutableArrayRef returned_array = CFArrayCreateMutable(nullptr, CFArrayGetCount(all_windows), nullptr);
    
    bool found = false;
    for (CFIndex i = 0; i < CFArrayGetCount(all_windows); ++i) {
        CFDictionaryRef window = reinterpret_cast<CFDictionaryRef>(CFArrayGetValueAtIndex(all_windows, i));
        
        CFNumberRef id_ref = reinterpret_cast<CFNumberRef>(CFDictionaryGetValue(window, kCGWindowNumber));
        
        CGWindowID id;
        CFNumberGetValue(id_ref, kCFNumberIntType, &id);
        auto it = windows_to_exclude.begin();
        for (; it != windows_to_exclude.end(); it++)
        {
            if (*it == id)
                break;
        }
        if (it != windows_to_exclude.end()) {
            found = true;
            continue;
        }
        CFArrayAppendValue(returned_array, reinterpret_cast<void *>(id));
    }
    CFRelease(all_windows);
    
    if (!found) {
        CFRelease(returned_array);
        returned_array = nullptr;
    }
    return returned_array;
}

@interface ViewController() <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation ViewController
{
    AVCaptureSession* _captureSession;
    CGDisplayStreamRef _stream_ref;
    BOOL _isCapture;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.isCancel = NO;
    _isCapture = NO;
    [self.capturePopUpButton removeAllItems];
    [self.capturePopUpButton addItemWithTitle:@"CGDisplayCreateImage"];
    [self.capturePopUpButton addItemWithTitle:@"CGWindowListCreateImageFromArray"];
    [self.capturePopUpButton addItemWithTitle:@"CGWindowListCreateImageFromArray Thread"];
    [self.capturePopUpButton addItemWithTitle:@"CGDisplayStream"];
    [self.capturePopUpButton addItemWithTitle:@"AVCaptureSession"];
    
    uint32_t count = 0;
    CGDirectDisplayID displayIDs[5] = {0};
    CGGetOnlineDisplayList(5, displayIDs, &count);
    [self.dispalyPopUpButton removeAllItems];
    NSString *title;
    for ( int i = 0; i < count; i++ ) {
        
        boolean_t isMain = CGDisplayIsMain(displayIDs[i]);
        if ( isMain ) {
            title = [NSString stringWithFormat:@"%d Main", displayIDs[i]];
        } else {
            title = [NSString stringWithFormat:@"%d", displayIDs[i]];
        }
        
        [self.dispalyPopUpButton addItemWithTitle:title];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)captureAction:(id)sender {
    
    if ( _isCapture ) {
        self.isCancel = YES;
        _isCapture = NO;
        
        if ( _captureSession ) {
            [_captureSession stopRunning];
        }
        if ( _stream_ref ) {
            CGDisplayStreamStop(_stream_ref);
        }
        
        [self.btn setTitle:@"Capture"];
        
    } else {
        [self.btn setTitle:@"Stop"];
        self.isCancel = NO;
        _isCapture = YES;
        
        NSWindow* window = [[self view] window];
        NSLog(@"%lu", (unsigned long)window.sharingType);
        if ( [self.exclusionCheckBox state] == NSOnState ) {
            [window setSharingType:NSWindowSharingNone];
        } else {
            [window setSharingType:NSWindowSharingReadWrite];
        }
        
        
        if ( self.capturePopUpButton.indexOfSelectedItem == 0 ) {
            [self captureDesktop1];
        } else if ( self.capturePopUpButton.indexOfSelectedItem == 1 ) {
            [self captureDesktop2];
        } else if ( self.capturePopUpButton.indexOfSelectedItem == 2 ) {
            [self captureDesktop3];
        } else if ( self.capturePopUpButton.indexOfSelectedItem == 3 ) {
            [self captureDesktop4];
        } else if ( self.capturePopUpButton.indexOfSelectedItem == 4 ) {
            [self captureDesktop5];
        }
    }
}

- (void)displayInfo:(CGDirectDisplayID) display {
    
    size_t wide = CGDisplayPixelsWide(display);
    size_t high = CGDisplayPixelsHigh(display);
    boolean_t isActive = CGDisplayIsActive(display);
    boolean_t isBuiltin = CGDisplayIsBuiltin(display);
    boolean_t isMain = CGDisplayIsMain(display);
    CGSize size = CGDisplayScreenSize(display);
    boolean_t useOpenGL = CGDisplayUsesOpenGLAcceleration(display);
    
    CGDisplayModeRef modeRef = CGDisplayCopyDisplayMode(display);
    size_t width = CGDisplayModeGetWidth(modeRef);
    size_t height = CGDisplayModeGetHeight(modeRef);
    double refreshRate = CGDisplayModeGetRefreshRate(modeRef);
    bool gui = CGDisplayModeIsUsableForDesktopGUI(modeRef);
    CGDisplayModeRelease(modeRef);
    
    NSLog(@"wide:%zu", wide);
    NSLog(@"high:%zu", high);
    NSLog(@"width:%zu", width);
    NSLog(@"height:%zu", height);
    NSLog(@"size:%@", NSStringFromSize(size));
    
    NSLog(@"isActive:%d", isActive);
    NSLog(@"isBuiltin:%d", isBuiltin);
    NSLog(@"isMain:%d", isMain);
    NSLog(@"useOpenGL:%d", useOpenGL);
    NSLog(@"gui:%d", gui);
    NSLog(@"refreshRate:%f", refreshRate);
    
    [self.sizeTextField setStringValue:[NSString stringWithFormat:@"%zux%zu", width, height]];
}

- (CGDirectDisplayID)getDirectDisplayID {
    uint32_t count = 0;
    CGDirectDisplayID displayIDs[5] = {0};
    CGGetOnlineDisplayList(3, displayIDs, &count);
    return displayIDs[self.dispalyPopUpButton.indexOfSelectedItem % 5];
}

- (CGWindowImageOption)getImageOption {
    if ( [self.retinaCheckBox state] == NSOnState ) {
        return kCGWindowImageNominalResolution;
    } else {
        return kCGWindowImageDefault;
    }
}

- (void)captureDesktop1 {
    uint32_t displayID = [self getDirectDisplayID];
    [self displayInfo:displayID];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while ( !self.isCancel ) {
            CGImageRef image = CGDisplayCreateImage(displayID);
            CGDataProviderRef provider = CGImageGetDataProvider(image);
            CGDataProviderCopyData(provider);
            CFRelease(image);
            [self calculateFps];
            usleep(10000);
        }
    });
}

- (void)captureDesktop2 {
    NSWindow* window = [[self view] window];
    uint32_t displayID = [self getDirectDisplayID];
    CGWindowImageOption imageOpt = [self getImageOption];
    [self displayInfo:displayID];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        std::vector<CGWindowID> excludes;
        CGWindowID windowId = (CGWindowID)[window windowNumber];
        excludes.push_back(windowId);
        CFArrayRef window_list = CreateWindowListWithExclusion(excludes);
        while ( !self.isCancel ) {
            CGImageRef image = CGWindowListCreateImageFromArray(CGDisplayBounds(displayID), window_list, imageOpt);
            CGDataProviderRef provider = CGImageGetDataProvider(image);
            CGDataProviderCopyData(provider);
            CFRelease(image);
            [self calculateFps];
            usleep(10000);
        }
    });
}

- (void)captureDesktop3 {
    NSWindow* window = [[self view] window];
    uint32_t displayID = [self getDirectDisplayID];
    CGWindowImageOption imageOpt = [self getImageOption];
    [self displayInfo:displayID];
    for ( int i = 0; i < 2 ; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            std::vector<CGWindowID> excludes;
            CGWindowID windowId = (CGWindowID)[window windowNumber];
            excludes.push_back(windowId);
            CFArrayRef window_list = CreateWindowListWithExclusion(excludes);
            while ( !self.isCancel ) {
                CGImageRef image = CGWindowListCreateImageFromArray(CGDisplayBounds(displayID), window_list, imageOpt);
                CGDataProviderRef provider = CGImageGetDataProvider(image);
                CGDataProviderCopyData(provider);
                CFRelease(image);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self calculateFps];
                });
                usleep(10000);
            }
        });
    }
}

- (void)captureDesktop4 {
    dispatch_queue_t dq = dispatch_queue_create("com.enkichen.osx", DISPATCH_QUEUE_SERIAL);
    uint32_t displayID = [self getDirectDisplayID];
    
    void* keys[5];
    void* values[5];
    CFDictionaryRef opts;
    
    keys[0] = (void *) kCGDisplayStreamShowCursor;
    values[0] = (void *) kCFBooleanFalse;
    
    float fps = 1.0 / 120.f;
    CFNumberRef minnumFrameTime = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &fps);
    keys[1] = (void*)kCGDisplayStreamMinimumFrameTime;
    values[1] = (void*)minnumFrameTime;

    keys[2] = (void *)kCGDisplayStreamPreserveAspectRatio;
    values[2] = (void *) kCFBooleanTrue;
    
    CGRect frame = [NSScreen mainScreen].frame;
    keys[3] = (void *)kCGDisplayStreamSourceRect;
    values[3] = (void *)CGRectCreateDictionaryRepresentation(frame);
    
    keys[4] = (void *)kCGDisplayStreamDestinationRect;
    values[4] = (void *)CGRectCreateDictionaryRepresentation(frame);
    
    opts = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 3, NULL, NULL);
    
    CGDisplayStreamRef stream_ref = CGDisplayStreamCreateWithDispatchQueue(displayID, 1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, opts, dq,
                                                                           ^(CGDisplayStreamFrameStatus status, uint64_t time, IOSurfaceRef frame, CGDisplayStreamUpdateRef ref) {
                                                            if (kCGDisplayStreamFrameStatusFrameComplete == status && NULL != frame) {
                                                                IOSurfaceLock(frame, kIOSurfaceLockReadOnly, NULL);
                                                                size_t plane_count = IOSurfaceGetPlaneCount(frame);
                                                                
                                                                if ( 2 == plane_count )
                                                                {
                                                                    size_t width = IOSurfaceGetWidthOfPlane(frame, 0);
                                                                    size_t height = IOSurfaceGetHeightOfPlane(frame, 0);
                                                                    
                                                                    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
                                                                    CVPixelBufferRef pixelBuffer = NULL;
                                                                    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                                                                                          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                                                                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                                                                                          &pixelBuffer);
                                                                    
                                                                    if (result != kCVReturnSuccess) {
                                                                        NSLog(@"Unable to create cvpixelbuffer %d", result);
                                                                        return;
                                                                    }
                                                                    
                                                                    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                                                                    uint8_t *ySrcPlane = (uint8_t*)IOSurfaceGetBaseAddressOfPlane(frame, 0);
                                                                    uint8_t *yDestPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                                                                    size_t yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
                                                                    size_t yPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
                                                                    memcpy(yDestPlane, ySrcPlane, yStride * yPlaneHeight);
                                                                    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                                                                    
                                                                    CVPixelBufferLockBaseAddress(pixelBuffer, 1);
                                                                    uint8_t *uvSrcPlane = (uint8_t*)IOSurfaceGetBaseAddressOfPlane(frame, 1);
                                                                    uint8_t *uvDestPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
                                                                    size_t uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
                                                                    size_t uvPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
                                                                    memcpy(uvDestPlane, uvSrcPlane, uvStride * uvPlaneHeight);
                                                                    CVPixelBufferUnlockBaseAddress(pixelBuffer, 1);
                                                                    
                                                                    CVPixelBufferRelease(pixelBuffer);
                                                                }
                                                                else
                                                                {
                                                                    NSLog(@"Error: unsupported plane count in the displaystream capture. Cannot setup the pixel buffer. Exiting now.\n");
                                                                    exit(EXIT_FAILURE);
                                                                }
                                                                
                                                                [self calculateFps];
                                                                IOSurfaceUnlock(frame, kIOSurfaceLockReadOnly, NULL);
                                                            }
                                                        });
    if (NULL == stream_ref) {
        NSLog(@"Error: failed to create a display stream that we use to capture the screen.\n");
    }
    
    _stream_ref = stream_ref;
    
    CGError err = CGDisplayStreamStart(stream_ref);
    
    if (kCGErrorSuccess != err) {
        printf("Error: failed to start the display stream capturer. CGDisplayStreamStart failed: %d .\n", err);
    }
}

- (void)captureDesktop5 {
    if ( !_captureSession ) {
        [self captureDesktopWithCaptureScreenInput];
    }
    [_captureSession startRunning];
}

- (void)captureDesktopWithCaptureScreenInput {
    
    _captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureVideoDataOutput* captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    
    captureOutput.videoSettings = videoSettings;
    
    if ([_captureSession canAddOutput:captureOutput]) {
        [_captureSession addOutput:captureOutput];
    }
    
    [captureOutput setSampleBufferDelegate:self
                                     queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    NSArray* currentInputs = [_captureSession inputs];
    // remove current input
    if ([currentInputs count] > 0) {
        AVCaptureInput* currentInput = (AVCaptureInput*)[currentInputs objectAtIndex:0];
        [_captureSession removeInput:currentInput];
    }
    
    // now create capture session input out of AVCaptureDevice
    uint32_t count = 0;
    CGDirectDisplayID displayIDs[3] = {0};
    CGGetOnlineDisplayList(3, displayIDs, &count);
    AVCaptureScreenInput* newCaptureInput = [[AVCaptureScreenInput alloc] initWithDisplayID:displayIDs[0]];
    
    newCaptureInput.minFrameDuration = CMTimeMake(1, 120);
    
    // try to add our new capture device to the capture session
    [_captureSession beginConfiguration];
    
    BOOL addedCaptureInput = NO;
    if ([_captureSession canAddInput:newCaptureInput]) {
        [_captureSession addInput:newCaptureInput];
        addedCaptureInput = YES;
    } else {
        addedCaptureInput = NO;
    }
    
    [_captureSession commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    const int kFlags = 0;
    CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (CVPixelBufferLockBaseAddress(videoFrame, kFlags) != kCVReturnSuccess) {
        return;
    }
    
    const int kYPlaneIndex = 0;
    const int kUVPlaneIndex = 1;
    
    uint8_t* baseAddress = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(videoFrame, kYPlaneIndex);
    size_t yPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(videoFrame, kYPlaneIndex);
    size_t yPlaneHeight = CVPixelBufferGetHeightOfPlane(videoFrame, kYPlaneIndex);
    
    size_t uvPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(videoFrame, kUVPlaneIndex);
    size_t uvPlaneHeight = CVPixelBufferGetHeightOfPlane(videoFrame, kUVPlaneIndex);
    size_t frameSize = yPlaneBytesPerRow * yPlaneHeight + uvPlaneBytesPerRow * uvPlaneHeight;
    
    CVPixelBufferUnlockBaseAddress(videoFrame, kFlags);
    
    [self calculateFps];
}

- (void)calculateFps {
    static uint32_t count = 0;
    static struct timeval tv1 = {0,0};
    struct timeval tv2;
    
    gettimeofday(&tv2, NULL);
    int64_t ints = millisecond(tv2) - millisecond(tv1);
    
    if ( ints >= 1000 ) {
        tv1 = tv2;
        NSLog(@"fps:%d", count);
        NSString *fps = [NSString stringWithFormat:@"%d", count];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.fpsTextField setStringValue:fps];
        });
        count = 0;
    }
    
    count++;
}

@end
