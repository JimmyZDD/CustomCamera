//
//  MyCameraController.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/6/29.
//  Copyright © 2016年 TuSDK. All rights reserved.
//

#import "MyCameraController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define kMainScreenWidth [UIScreen mainScreen].bounds.size.width
#define kMainScreenHeight  [UIScreen mainScreen].bounds.size.height
#define ShowAlert(title) [[[UIAlertView alloc] initWithTitle:@"提示" message:title delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show]

@interface MyCameraController ()<UIGestureRecognizerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) IBOutlet UIView *preview;

//AVFoundation

/**
 *  创建一个对焦队列
 */
@property (nonatomic) dispatch_queue_t sessionQueue;

/**
 *
 */
@property (nonatomic, strong) AVCaptureSession *session;

/**
 *  input
 */
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;

/**
 *  stillImageOutput
 */
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
/**
 *  人脸识别
 */
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
/**
 *  对焦的框
 */
@property (nonatomic, strong) UIImageView *focusImageView;
/**
 *  人脸识别框
 */
@property (nonatomic, strong) UIImageView *faceImageView;


/**
 *  previewLayer
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

/**
 *  beginScale
 */
@property (nonatomic, assign) CGFloat beginGestureScale;

/**
 *  effectiveScale
 */
@property (nonatomic, assign) CGFloat effectiveGestureScale;

/**
 *  记录（record） CameraPostion
 */
@property (nonatomic, assign) BOOL isUsingFrontFacingCamera;

@property (nonatomic, assign) BOOL isStartFaceRecognition;

/**
 *  读取系统相册
 */
@property (nonatomic, strong) UIImagePickerController *picker;

@property (weak, nonatomic) IBOutlet UIToolbar *topToolBar;

@end

@implementation MyCameraController


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 关闭 session
    if (self.session) [self.session stopRunning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
     [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    // 开启 session
    if (self.session) [self.session startRunning];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(topToolBarFrameChange) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    
    self.effectiveGestureScale = self.beginGestureScale = 1.0f;
    
    [self createQueue];
    
    [self initAVCapture];
    
    [self setupImagePicker];
    
    [self setupPinchGesture];
    
    [self initfocusImageWithParent:_preview];
    
    if (_canFaceRecognition) {
        [self initFaceImageWithParent:_preview];
    }
}

/**
 *  创建一个队列，防止阻塞主线程
 */
- (void)createQueue {
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    self.sessionQueue = sessionQueue;
}
/**
 *  对焦的框
 */
- (void)initfocusImageWithParent:(UIView *)view;
{
    if (self.focusImageView) {
        return;
    }
    self.focusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"touch_focus_x.png"]];
    self.focusImageView.hidden = YES;
//    _focusImageView.backgroundColor = [UIColor redColor];
    _focusImageView.bounds = CGRectMake(0, 0, 100, 100);
    if (view.superview!=nil) {
        [self.view bringSubviewToFront:_focusImageView];
        [view.superview addSubview:self.focusImageView];
    }else{
        self.focusImageView = nil;
    }
}
/**
 *  脸部识别的框
 *
 *  @param view
 */
- (void)initFaceImageWithParent:(UIView *)view;
{
    if (self.faceImageView) {
        return;
    }
    self.faceImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"face.png"]];
    self.faceImageView.alpha = 0;
    if (view.superview) {
        [view.superview addSubview:self.faceImageView];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int32_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.isStartFaceRecognition = YES;
        });
    }else{
        self.faceImageView = nil;
    }
}


#pragma mark -- 初始化所有对象
/**
 *  initAVCapture
 */
- (void)initAVCapture {
    self.session = [AVCaptureSession new];
    
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    //闪光灯（自动）
    [device setFlashMode:AVCaptureFlashModeAuto];
    [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
     
    [device unlockForConfiguration];
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc]initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
        ShowAlert(error.description);
    }
    
    
    self.stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_stillImageOutput setOutputSettings:outputSettings];
    
    
    if ([_session canAddInput:_videoInput])
        [_session addInput:_videoInput];
    if ([_session canAddOutput:_stillImageOutput])
        [_session addOutput:_stillImageOutput];
    if (_canFaceRecognition) {
        [self addMetadataOutputTypeFace];
    }
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:_session];
    [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _previewLayer.frame = CGRectMake(0, 0, kMainScreenWidth, kMainScreenHeight - 88);
    _preview.layer.masksToBounds = YES;
    [_preview.layer addSublayer:_previewLayer];
}
/**
 *  添加 可以检索从设备上支持人脸检测的avcapturemetadataoutput对象输出该类的实例。
 */
- (void)addMetadataOutputTypeFace {
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([_session canAddOutput:metadataOutput]) {
        [_session addOutput:metadataOutput];
        [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeFace]];
        [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        self.metadataOutput = metadataOutput;
    }
}

#pragma mark -- 拍照按钮点击事件

/**
 *  获取设备方向的方法，再配置图片输出
 *
 *  @param devOrientation 设备方向
 *
 *  @return 图片输出方向
 */
- (AVCaptureVideoOrientation)avOrientationForDeviceOrentation:(UIDeviceOrientation)devOrientation {
    AVCaptureVideoOrientation result;
    
    if (devOrientation == UIDeviceOrientationLandscapeLeft) {
        result = AVCaptureVideoOrientationLandscapeRight;
    } else if (devOrientation == UIDeviceOrientationLandscapeRight) {
        result = AVCaptureVideoOrientationLandscapeLeft;
    }
    return result;
}
- (IBAction)takePhoto:(id)sender {
    
    AVCaptureConnection *stillImageConnection = [_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    
    UIDeviceOrientation currentDeviceOrientation= [[UIDevice currentDevice]orientation];
    AVCaptureVideoOrientation avCaptureOrentation = [self avOrientationForDeviceOrentation:currentDeviceOrientation];
    
    [stillImageConnection setVideoOrientation:avCaptureOrentation];
    [stillImageConnection setVideoScaleAndCropFactor:_effectiveGestureScale];
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        
        CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
        
        ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
        if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied) {
            ShowAlert(@"相册访问被限制或拒绝");
            return;
        }
        ALAssetsLibrary *library = [ALAssetsLibrary new];
        [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
            
        }];
    }];
}

#pragma mark -- 去相册
- (void)setupImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc]init];
    picker.view.backgroundColor = [UIColor orangeColor];
    UIImagePickerControllerSourceType sourcheType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.sourceType = sourcheType;
    picker.delegate = self;
    picker.allowsEditing = NO;
    
    self.picker = picker;
}
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info;
{
    [picker dismissViewControllerAnimated:NO completion:nil];
}
- (IBAction)gotoAlbum:(id)sender {
    
    [self presentViewController:_picker animated:YES completion:nil];
    
}

#pragma mark -- 返回按钮

- (IBAction)backBarButtonClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -- 切换前后置摄像头

- (IBAction)switchCameraPostion:(UIBarButtonItem *)sender {
    AVCaptureDevicePosition desiredPostion;
    if (_isUsingFrontFacingCamera) {
        desiredPostion = AVCaptureDevicePositionBack;
        [sender setTitle:[@"CameraPostion" stringByAppendingString:@"(后置)"]];
    } else {
        desiredPostion = AVCaptureDevicePositionFront;
        [sender setTitle:[@"CameraPostion" stringByAppendingString:@"(前置)"]];
    }
    
    for (AVCaptureDevice *dev in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        // 从数组中取出 和 配置摄像头前后相同的AVCaptureDevice 然后配置DeviceInput 放到_session的input中
        if (dev.position == desiredPostion) {
            [_session beginConfiguration];
            
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:nil];
            for (AVCaptureInput *oldInput in _session.inputs) {
                [_session removeInput:oldInput];
            }
            [_session addInput:input];
            
            [_session commitConfiguration];
            break;
        }
    }
    _isUsingFrontFacingCamera = !_isUsingFrontFacingCamera;
}

#pragma mark -- 闪光灯点击事件

- (IBAction)flashButtonClick:(id)sender {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    
    if ([device hasFlash]) {
        if (device.flashMode == AVCaptureFlashModeAuto) {
            device.flashMode = AVCaptureFlashModeOn;
            [sender setValue:@"闪光的（开）" forKey:@"title"];
        } else if (device.flashMode == AVCaptureFlashModeOn) {
            device.flashMode = AVCaptureFlashModeOff;
            [sender setValue:@"闪光的（关）" forKey:@"title"];
        } else {
            device.flashMode = AVCaptureFlashModeAuto;
            [sender setValue:@"闪光的（自动）" forKey:@"title"];
        }
    } else {
        ShowAlert(@"闪光的不可用");
    }
    [device unlockForConfiguration];
}

#pragma mark -- 通过捏合手势改变焦距

- (void)setupPinchGesture {
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(handelPinchGesture:)];
    pinch.delegate = self;
    [self.preview addGestureRecognizer:pinch];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.beginGestureScale = self.effectiveGestureScale;
    }
    return YES;
}

/**
 *  缩放手势用于调整焦距
 *
 *  @param pinchGesture 手势
 */
- (void)handelPinchGesture:(UIPinchGestureRecognizer *)pinchGesture {
    NSLog(@"pinchGesture.scale:%f",pinchGesture.scale);
    
    BOOL allTouchesAreOnThePreviewLayer = YES;
    
    NSUInteger numTouches = [pinchGesture numberOfTouches], i;
    for (i = 0; i<numTouches; i++)
    {
        CGPoint location = [pinchGesture locationOfTouch:i inView:_preview];
#warning 注意是fromLayer
        CGPoint convertedLocation = [_previewLayer convertPoint:location fromLayer:_previewLayer.superlayer];
        
        if (![_previewLayer containsPoint:convertedLocation])
        {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if (allTouchesAreOnThePreviewLayer)
    {
        _effectiveGestureScale = _beginGestureScale*pinchGesture.scale;
        if (_effectiveGestureScale < 1.0) {
            _effectiveGestureScale = 1.0f;
        }
        
        CGFloat maxScaleAndCropFactor = [[_stillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        if (_effectiveGestureScale > maxScaleAndCropFactor) {
            _effectiveGestureScale = maxScaleAndCropFactor;
        }
        
        NSLog(@"%f---%f***%f",_beginGestureScale,_effectiveGestureScale,maxScaleAndCropFactor);
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [_previewLayer setAffineTransform:CGAffineTransformMakeScale(_effectiveGestureScale, _effectiveGestureScale)];
        [CATransaction commit];
    }
}
#pragma mark -- 手动对焦
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint point = [touch locationInView:_preview];
        [self focusAtPoint:point];
    }
}
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1-point.x/size.width );
    NSError *error;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if ([device lockForConfiguration:&error]) {
        //对焦模式和对焦点
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [device setFocusPointOfInterest:focusPoint];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        //曝光模式和曝光点
        if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [device setExposurePointOfInterest:focusPoint];
            [device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        [device unlockForConfiguration];
        //设置对焦动画
        _focusImageView.center = point;
        _focusImageView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            _focusImageView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                _focusImageView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                _focusImageView.hidden = YES;
            }];
        }];
    }
    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
