//
//  MyVideoController.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/6/30.
//  Copyright © 2016年 TuSDK. All rights reserved.
//

// 宏一个简单警告框
#define ShowAlert(title) [[[UIAlertView alloc] initWithTitle:@"提示" message:title delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show]
// 自定义Log信息
#ifdef DEBUG
#define LOG(...) NSLog(__VA_ARGS__);
#define LOG_METHOD NSLog(@"%s", __func__);
#else
#define LOG(...);
#define LOG_METHOD;
#endif

#import "MyVideoController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface MyVideoController ()<AVCaptureFileOutputRecordingDelegate>//视频文件输出代理

/**
 *  捕获会话层
 */
@property (nonatomic, strong) AVCaptureSession *captureSession;

/**
 *  从捕获设备获得输入数据
 */
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
/**
 *  视频文件输出流
 */
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
/**
 *  相机拍摄预览层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识


@property (weak, nonatomic) IBOutlet UIView *preView;

@end

@implementation MyVideoController


#pragma mark -- 初始化视频设备
- (void)setupCapture {
    self.captureSession = [AVCaptureSession new];
    
    // 设置视图分辨率
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    }
    
    // 添加一个视频输入设备
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        ShowAlert(@"获取摄像头错误");
        return;
    }
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    
    // 添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        ShowAlert(@"获取音频设备错误");
        return;
    }
    if ([_captureSession canAddInput:audioCaptureDeviceInput]) {
        [_captureSession addInput:audioCaptureDeviceInput];
    }

    // 添加一个MovieFile输出
    self.captureMovieFileOutput = [AVCaptureMovieFileOutput new];
    AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    // 支持自动稳定技术（防抖、修正）
    if ([captureConnection isVideoMaxFrameDurationSupported]) {
        captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    // 创建视频预览层，用于实时展示摄像头状态
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:_captureSession];
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    _captureVideoPreviewLayer.frame = _preView.bounds;
    LOG(@"%@",NSStringFromCGRect(_preView.frame));
    _preView.layer.masksToBounds = YES;
    [_preView.layer addSublayer:_captureVideoPreviewLayer];

}



#pragma mark -- 视频输出代理AVCaptureFileOutputRecordingDelegate @required 视频输出代理
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;
{
    LOG(@"视频录制完成.");
    
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied) {
        ShowAlert(@"相册访问被限制或拒绝");
        return;
    }

    //视频录入完成之后在后台将视频存储到相簿
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            LOG(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
            return;
        }
        NSLog(@"成功保存视频到相簿.");
    }];

}
/**
 *  返回一个Documents路径
 *
 *  @return Documents
 */
- (NSString *)documentDir
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = nil;
    //    NSString *path = [NSHomeDirectory() stringByAppendingString:@""];
    if ([paths count] > 0) {
        docDir = [paths objectAtIndex:0];
    }
    return docDir;
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    LOG(@"开始录制...");
}

#pragma mark -- 控制器视图方法

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupCapture];
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    
    if (_captureSession) [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];

    
    if (_captureSession) [self.captureSession stopRunning];
}
#pragma mark -- UIViewController (UIViewControllerRotation)
//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//    LOG(@"toInterfaceOrientation:%d",toInterfaceOrientation);
//}
//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//    LOG(@"fromInterfaceOrientation:%d",fromInterfaceOrientation);
//}
#pragma mark -- UI方法
#pragma mark -- 录制按钮点击事件
- (IBAction)recordBtnClick:(UIBarButtonItem *)sender {
    // 根据输出获取连接
    AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    if (![_captureMovieFileOutput isRecording]) {
        [sender setTitle:@"isRecording"];
        // 预览图层和视频方向保持一致
        captureConnection.videoOrientation = _captureVideoPreviewLayer.connection.videoOrientation;
        NSString *outputFielPath = [[self documentDir] stringByAppendingString:@"/aaa.mov"];
        LOG(@"save path :%@",outputFielPath);
        NSURL *fileUrl = [NSURL fileURLWithPath:outputFielPath];
        [_captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    } else {
        [self.captureMovieFileOutput stopRecording];
        [sender setTitle:@"stopRecording"];
    }
    
}
#pragma mark -- 相册按钮点击事件
- (IBAction)albumBtnClick:(id)sender {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark -- 返回按钮
- (IBAction)backBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
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
