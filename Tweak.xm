#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

extern "C" CGImageRef UIGetScreenImage(void);

@interface ScreenRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate, UIAlertViewDelegate>

@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL hasStartedSession;
@property (nonatomic, assign) BOOL recordAudio; 

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) AVCaptureSession *audioSession;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, assign) CFAbsoluteTime startTime; 

+ (instancetype)sharedInstance;
- (void)toggleRecording;
- (void)promptForAudio;
- (void)startRecordingWithAudio:(BOOL)useAudio;
@end

@implementation ScreenRecorder

+ (instancetype)sharedInstance {
    static ScreenRecorder *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (void)toggleRecording {
    if (self.isRecording) {
        [self stopRecording];
    } else {
        [[NSFileManager defaultManager] createFileAtPath:@"/tmp/ScreenRec.active" contents:nil attributes:nil];
        [self promptForAudio];
    }
}

- (void)promptForAudio {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Screen recording" 
                                                    message:@"Record sound from a microphone?" 
                                                   delegate:self 
                                          cancelButtonTitle:@"Cancel" 
                                          otherButtonTitles:@"No sound", @"With sound", nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        NSLog(@"[ScreenRec6] The user cancelled the recording..");
        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/ScreenRec.active" error:nil];
    } else if (buttonIndex == 1) {
        [self startRecordingWithAudio:NO];
    } else if (buttonIndex == 2) {
        [self startRecordingWithAudio:YES];
    }
}

- (void)startRecordingWithAudio:(BOOL)useAudio {
    if (self.isRecording) return;
    
    self.isRecording = YES;
    self.recordAudio = useAudio;
    self.hasStartedSession = NO;
    
    NSLog(@"[ScreenRec6] Start recording. Audio: %@", useAudio ? @"ON" : @"OFF");
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    NSString *fileName = [NSString stringWithFormat:@"ScreenRecord_%@.mp4", dateString];
    NSString *path = [@"/var/mobile/Documents/" stringByAppendingPathComponent:fileName];
    NSURL *url = [NSURL fileURLWithPath:path];


    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat scale = [[UIScreen mainScreen] scale];
    int videoWidth = screenSize.width * scale;
    int videoHeight = screenSize.height * scale;
    videoWidth = videoWidth - (videoWidth % 16);
    videoHeight = videoHeight - (videoHeight % 16);

    self.writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:nil];
    
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @(videoWidth),
        AVVideoHeightKey: @(videoHeight)
    };
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *pixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (id)kCVPixelBufferWidthKey: @(videoWidth),
        (id)kCVPixelBufferHeightKey: @(videoHeight),
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    [self.writer addInput:self.videoInput];

    if (self.recordAudio) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];

        NSDictionary *audioSettings = @{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: @1,
            AVSampleRateKey: @44100.0,
            AVEncoderBitRateKey: @64000
        };
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        self.audioInput.expectsMediaDataInRealTime = YES;
        [self.writer addInput:self.audioInput];

        self.audioSession = [[AVCaptureSession alloc] init];
        AVCaptureDevice *micDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *micInput = [AVCaptureDeviceInput deviceInputWithDevice:micDevice error:nil];
        if ([self.audioSession canAddInput:micInput]) [self.audioSession addInput:micInput];
        
        AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        self.audioQueue = dispatch_queue_create("com.vorotyntsev.audioQueue", NULL);
        [audioOutput setSampleBufferDelegate:self queue:self.audioQueue];
        if ([self.audioSession canAddOutput:audioOutput]) [self.audioSession addOutput:audioOutput];
        
        [self.writer startWriting];
        [self.audioSession startRunning];
    } else {
        [self.writer startWriting];
        [self.writer startSessionAtSourceTime:kCMTimeZero];
        self.startTime = CFAbsoluteTimeGetCurrent();
        self.hasStartedSession = YES;
    }
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrame:)];
    self.displayLink.frameInterval = 4; // 15 FPS
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.isRecording || !self.recordAudio) return;
    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if (!self.hasStartedSession) {
        [self.writer startSessionAtSourceTime:timestamp];
        self.hasStartedSession = YES;
        NSLog(@"[ScreenRec6] A/V Сессия запущена по таймингу микрофона");
    }
    
    if (self.audioInput.readyForMoreMediaData) {
        [self.audioInput appendSampleBuffer:sampleBuffer];
    }
}

- (void)captureFrame:(CADisplayLink *)link {
    if (!self.hasStartedSession) return; 
    if (!self.videoInput.readyForMoreMediaData) return;
    
    CGImageRef cgImage = UIGetScreenImage();
    if (!cgImage) return;
    
    CGSize size = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, self.adaptor.pixelBufferPool, &pixelBuffer);
                                          
    if (pixelBuffer != NULL) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height,
                                                     8, CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                     rgbColorSpace, kCGImageAlphaNoneSkipFirst);
        
        if (context) {
            CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), cgImage);
            CGContextRelease(context);
        }
        
        CGColorSpaceRelease(rgbColorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

        CMTime presentTime;
        if (self.recordAudio) {
            presentTime = CMClockGetTime(CMClockGetHostTimeClock()); 
        } else {
            CFTimeInterval elapsedTime = CFAbsoluteTimeGetCurrent() - self.startTime;
            presentTime = CMTimeMake(elapsedTime * 600, 600); 
        }
        
        [self.adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentTime];
        CVPixelBufferRelease(pixelBuffer);
    }
    CGImageRelease(cgImage);
}

- (void)stopRecording {
    if (!self.isRecording) return;
    self.isRecording = NO;
    NSLog(@"[ScreenRec6] Stop recording...");

    [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/ScreenRec.active" error:nil];

    [self.displayLink invalidate];
    self.displayLink = nil;
    
    if (self.recordAudio) {
        [self.audioSession stopRunning];
        self.audioSession = nil;
        [self.audioInput markAsFinished];

        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
    
    [self.videoInput markAsFinished];
    
    [self.writer finishWritingWithCompletionHandler:^{
        NSLog(@"[ScreenRec6] File saved successfully!");
    }];
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:[ScreenRecorder sharedInstance] 
                                             selector:@selector(toggleRecording) 
                                                 name:@"com.vorotyntsev.screenrec6.toggle" 
                                               object:nil];
}
%end