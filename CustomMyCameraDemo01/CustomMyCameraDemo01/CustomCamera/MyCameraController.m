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
/**
 *  宏一个简单的警告框
 *
 *  @param title 提示内容
 *
 *  @return nil
 */
#define ShowAlert(title) [[[UIAlertView alloc] initWithTitle:@"提示" message:title delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show]
// 自定义Log信息
#ifdef DEBUG
#define LOG(...) NSLog(__VA_ARGS__);
#define LOG_METHOD NSLog(@"%s", __func__);
#else
#define LOG(...);
#define LOG_METHOD;
#endif

@interface MyCameraController ()<UIGestureRecognizerDelegate,  AVCaptureMetadataOutputObjectsDelegate> {
    UIView *imgView;
}

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
 *  AVMediaTypeVideo
 */
@property (nonatomic, strong) AVCaptureDevice *device;
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
@property (nonatomic, strong) UIView *faceCircleView;

/**
 *  显示缩放比例
 */
@property (nonatomic, retain) UILabel *scaleLabel;

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

#pragma mark -- viewController 一些方法


- (instancetype)init
{
    self = [super init];
    if (self) {
         }
    return self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_device removeObserver:self forKeyPath:@"adjustingFocus"];
    
    // 关闭 session
    if (self.session) [self.session stopRunning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [_device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    // 开启 session
    if (self.session) [self.session startRunning];
}

- (void)awakeFromNib {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _isStartFaceRecognition  = YES;
    self.isPreviewImg = YES;
    self.isManualFocus = NO;
    self.canFaceRecognition = YES;
    
    self.effectiveGestureScale = self.beginGestureScale = 1.0f;
    
    [self createQueue];
    
    [self initAVCapture];
    
    [self setupImagePicker];
    
    [self setupPinchGesture];
    
    [self setupTapGesture];
    
    [self initfocusImageWithParent:_preview];
    
    [self initFaceCircleView];
        
    [self initScaleLabel];
}

#pragma mark -- 监听对焦事件

-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if([keyPath isEqualToString:@"adjustingFocus"]){
        BOOL adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        LOG(@"Is adjusting focus? %@", adjustingFocus ?@"YES":@"NO");
        LOG(@"Change dictionary: %@", change);
    }
}

- (IBAction)switchPreviewOrientation:(UISwitch *)sender {
    
    
}

#pragma mark -- 配置相机相关组件


/**
 *  创建一个队列，防止阻塞主线程
 */
- (void)createQueue {
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    self.sessionQueue = sessionQueue;
}

- (void)initScaleLabel {
    self.scaleLabel = [[UILabel alloc]initWithFrame:CGRectMake(kMainScreenWidth - 70, 60, 60, 20)];
    
    _scaleLabel.hidden = YES;
    
    _scaleLabel.textColor = [UIColor orangeColor];
    
    _scaleLabel.text = @"1X";
    
    [_preview addSubview:_scaleLabel];
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

- (void)initFaceCircleView {
    self.faceCircleView = [UIView new];
    _faceCircleView.backgroundColor = [[UIColor lightGrayColor]colorWithAlphaComponent:0];
    _faceCircleView.layer.borderColor = [[UIColor orangeColor] CGColor];
    _faceCircleView.layer.borderWidth = 2;
    [_preview addSubview:_faceCircleView];
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
    // 是否手动对焦
    if (!_isManualFocus) {
        [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
    [device unlockForConfiguration];
    
    self.device = device;
    
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc]initWithDevice:device error:&error];
    if (error) {
        LOG(@"%@",error);
        ShowAlert(error.description);
    }
    
    
    self.stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_stillImageOutput setOutputSettings:outputSettings];
    
    
    if ([_session canAddInput:_videoInput])
        [_session addInput:_videoInput];
    if ([_session canAddOutput:_stillImageOutput])
        [_session addOutput:_stillImageOutput];
    // 添加人脸识别MetadataOutput

    if (_canFaceRecognition && [[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
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
#pragma -mark AVCaptureMetadataOutputObjectsDelegate  人脸识别代理方法
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (self.canFaceRecognition) {
        /**
         *  AVMetadataObject是一个抽象类，定义了由AVFoundation所使用的元数据对象的接口。
         */
        for(AVMetadataObject *metadataObject in metadataObjects) {
#warning AVMetadataObjectTypeFace(人脸识别)
            if([metadataObject.type isEqualToString:AVMetadataObjectTypeFace]) {
                [self showFaceImageWithFrame:metadataObject.bounds];
            }
        }
    }
}
/**
 *  人脸框的动画
 *
 *  @param rect
 */
- (void)showFaceImageWithFrame:(CGRect)rect
{
    if (self.isStartFaceRecognition) {
        self.isStartFaceRecognition = NO;
        
        _faceCircleView.frame = CGRectMake(rect.origin.y * self.previewLayer.frame.size.width - 10, rect.origin.x * self.previewLayer.frame.size.height - 70, rect.size.width * self.previewLayer.frame.size.width * 2, rect.size.height * self.previewLayer.frame.size.height);
        
        _faceCircleView.transform = CGAffineTransformMakeScale(1.5, 1.5);
//        __weak typeof(self) weak = self;
        LOG(@"_faceCircleView.frame%@",NSStringFromCGRect(_faceCircleView.frame));
        [UIView animateWithDuration:0.3f animations:^{
            _faceCircleView.alpha = 1;

            _faceCircleView.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:2.f animations:^{
                _faceCircleView.alpha = 0;
            } completion:^(BOOL finished) {
                 self.isStartFaceRecognition = YES;
            }];
        }];
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
        /**
         *  是否拍照后预览
         */
        if (_isPreviewImg)
        {
            imgView = [[UIView alloc]initWithFrame:self.view.frame];
            imgView.clipsToBounds = YES;
            imgView.backgroundColor = [[UIColor darkGrayColor]colorWithAlphaComponent:0.2];
            UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageWithData:jpegData]];
            imageView.frame = imgView.frame;
            
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(20, 20, 40, 40);
            btn.backgroundColor = [UIColor cyanColor];
            [btn setTitle:@"返回" forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(disMissImgView) forControlEvents:UIControlEventTouchUpInside];
            
            [imgView addSubview:imageView];
            [imgView addSubview:btn];
            [self.view.window addSubview:imgView];
        }
        
        ALAssetsLibrary *library = [ALAssetsLibrary new];
        [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
            
        }];
    }];
}

- (void)disMissImgView {
    [imgView removeFromSuperview];
}

#pragma mark -- 去相册
- (void)setupImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc]init];
    UIImagePickerControllerSourceType sourcheType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.sourceType = sourcheType;
    picker.allowsEditing = YES;
    
    self.picker = picker;
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
        
        LOG(@"dev:%d",dev.position);
        
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
    
    _scaleLabel.hidden = NO;
    
    return YES;
}

/**
 *  缩放手势用于调整焦距
 *
 *  @param pinchGesture 手势
 */
- (void)handelPinchGesture:(UIPinchGestureRecognizer *)pinchGesture {
    LOG(@"pinchGesture.scale:%f",pinchGesture.scale);
    
    if (pinchGesture.state == UIGestureRecognizerStateEnded) {
        _scaleLabel.hidden = YES;
    }
    
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
        
        LOG(@"%f---%f***%f",_beginGestureScale,_effectiveGestureScale,maxScaleAndCropFactor);
        
        _scaleLabel.text = [NSString stringWithFormat:@"%.2fX",_effectiveGestureScale];
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [_previewLayer setAffineTransform:CGAffineTransformMakeScale(_effectiveGestureScale, _effectiveGestureScale)];
        [CATransaction commit];
    }
}
#pragma mark -- 手动对焦


- (void)setupTapGesture {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    
    [self.preview addGestureRecognizer:tap];
}
- (void)tapAction:(UITapGestureRecognizer *)tap {
    
    CGPoint point = [tap locationInView:_preview];
    [self focusAtPoint:point];
    
}
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = _previewLayer.bounds.size;
    
    /**
     *  setExposurePointOfInterest：focusPoint 函数后面Point取值范围是取景框左上角（0，0）到取景框右下角（1，1）之间。官方是这么写的：
     *我也试了按这个来但位置就是不对，只能按上面的写法才可以。前面是点击位置的y/PreviewLayer的高度，后面是1-点击位置的x/PreviewLayer的宽度

     */
    CGPoint focusPoint = CGPointMake(point.y/size.height, 1-point.x/size.width);
    NSError *error;
    
    
    if ([_device lockForConfiguration:&error]) {
        //对焦模式和对焦点
        if ([_device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [_device setFocusPointOfInterest:focusPoint];
            [_device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        //曝光模式和曝光点
        if ([_device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [_device setExposurePointOfInterest:focusPoint];
            [_device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        [_device unlockForConfiguration];
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
#pragma mark -- 分段控制器切换SessionPreset

- (IBAction)captureSessionPreset:(UISegmentedControl *)sender {
    LOG(@"%d",sender.selectedSegmentIndex);
    switch (sender.selectedSegmentIndex) {
        case 0:
            if ([_session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
                [_session setSessionPreset:AVCaptureSessionPresetHigh];
            }
            break;
        case 1:
            if ([_session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
                [_session setSessionPreset:AVCaptureSessionPresetMedium];
            }
            break;
        case 2:
            if ([_session canSetSessionPreset:AVCaptureSessionPresetLow]) {
                [_session setSessionPreset:AVCaptureSessionPresetLow];
            }
            break;
        default:
            break;
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
