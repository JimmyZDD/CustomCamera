//
//  MyMovieWithAssetWriterController.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/7/1.
//  Copyright © 2016年 TuSDK. All rights reserved.
//



#import "MyMovieWithAssetWriterController.h"
#import <AVFoundation/AVFoundation.h>
#import "MPMoviePlayController.h"

#define kMainScreenWidth [UIScreen mainScreen].bounds.size.width
#define kMainScreenHeight  [UIScreen mainScreen].bounds.size.height
/**
 *  宏一个简单的警告框
 *
 *  @param title 提示内容
 *
 *  @return nil
 */
#define ShowAlert(...) [[[UIAlertView alloc] initWithTitle:@"提示" message:__VA_ARGS__ delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show]
// 自定义Log信息
#ifdef DEBUG
#define LOG(...) NSLog(__VA_ARGS__);
#define LOG_METHOD NSLog(@"%s", __func__);
#else
#define LOG(...);
#define LOG_METHOD;
#endif


static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};//弧度角度转换

@interface MyMovieWithAssetWriterController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

/**
 *  是否开始录制
 */
@property (nonatomic, assign) BOOL started;
/**
 *  主要用在视频方面  CMTime 帧 和 时间 專門用來表示影片時間用的類別
 CMTimeMake(a,b)    a当前第几帧, b每秒钟多少帧.当前播放时间a/b
 
 CMTimeMakeWithSeconds(a,b)    a当前时间,b每秒钟多少帧.
 */
@property (nonatomic, assign) CMTime frameDuration;
/**
 *  下一个传输
 Rational time value represented as int64/int32.
 */
@property (nonatomic, assign) CMTime nextPTS;
/**
 *  捕获设备会话层
 */
@property (nonatomic, retain) AVCaptureSession* captureSession;

/**
 *  AVAssetWriter写入媒体数据到一个新的文件提供的服务，
 */
@property (nonatomic, retain) AVAssetWriter *assetWriter;

/**
 *  附加媒体样本包装为CMSamplebuffer对象
 */
@property (nonatomic, retain) AVAssetWriterInput *assetWriterInput;

/**
 *  视频数据输出
 */
@property (nonatomic, retain) AVCaptureVideoDataOutput* videoOutput;

/**
 *  打开 Mov 链接
 */
@property (nonatomic, retain) NSURL *outputMovURL;

/**
 *  打开 Mp4 链接
 */
@property (nonatomic, retain) NSURL* outputMp4URL;
/**
 *  进度条
 */
@property (nonatomic, retain) UIProgressView* progressBar;

/**
 *  预览层俯视图
 */
@property (weak, nonatomic) IBOutlet UIView *preview;

/**
 *  视频当前帧
 */

@property (nonatomic, assign) NSInteger currentFrame;
/**
 *  视频最大帧数
 */
@property (nonatomic, assign) NSInteger maxFrame;


@property (weak, nonatomic) IBOutlet UIToolbar *topBar;

@end

@implementation MyMovieWithAssetWriterController
#pragma mark - capture method
- (void)setupAVCapture {
    NSError *error = nil;
    self.captureSession = [AVCaptureSession new];
    // 设置分辨率
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    }
    // 为会话层添加输入设备
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    LOG(@"backCamera.position:%d",backCamera.position);
    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
    if (error) {
        ShowAlert(@"初始化相机出错");
        return;
    }
    if ([_captureSession canAddInput:captureDeviceInput]) {
        [_captureSession addInput:captureDeviceInput];
    }
    
    // 为会话层添加输出设备
    self.videoOutput = [AVCaptureVideoDataOutput new];
    // 丢弃最后一帧
    [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    if ([_captureSession canAddOutput:_videoOutput]) {
        [_captureSession addOutput:_videoOutput];
    }
    
    // 创建一个串行队列 来处理输出设备的回调事件
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [_videoOutput setSampleBufferDelegate:self queue:queue];
    // dispatch_release(queue);// 手动释放 在ARC下GCD队列自动释放
    _videoOutput.videoSettings = @{
            (id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
#pragma mark -- 这个歌是什么
            // 分辨率缓存 分辨率格式化Key   初始化摄像头的时候，设置采集格式是32bit rgb的
                                   };
    // 初始化视屏预览层
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [previewLayer setFrame:[_preview bounds]];
    _preview.layer.masksToBounds = YES;
    [_preview.layer addSublayer:previewLayer];
}
/**
 *  初始化一个文件写入类
 *
 *  @param fileURL              文件路径
 *  @param formatDescriptionRef 引用一个CMFormatDescription，描述的特定类型（音频，视频，混合音视频等等）的媒体的CF对象。
 */
- (BOOL)setupAssetWriterForURL:(NSURL *)fileURL formatDescription:(CMFormatDescriptionRef)formatDescriptionRef {
    NSError *error = nil;
    
    // allocate the writer object with our output file URL
    // 使用输出文件的路径初始化写对象
    self.assetWriter = [[AVAssetWriter alloc]initWithURL:fileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        ShowAlert(@"初始化assetWriter对象出错");
        return NO;
    }
    
    // initialized a new input for video to receive sample buffers for writing
    // 初始化一个新的输入设备来接收原样数据用来写入
    // passing nil for outputSettings instructs the input to pass through appended samples, doing no processing before they are written
    // 通过设置outputSettings为空指示 传递通过附加样本,不做任何如理在写入之前
    // 下面这个参数，设置图像质量，数字越大，质量越好
#pragma mark -- 设置一些输出的参数
    /**
     *  设置平均比特率
     */
    NSDictionary *videoCompressionProps =
    @{
      AVVideoAverageBitRateKey:[NSNumber numberWithDouble:512*1024.0]
      // 平均比特率
     };
    // 设置编码和宽高比。宽高比最好和摄像比例一致，否则图片可能被压缩或拉伸 压缩属性
    NSDictionary *outputSettingsDic =
    @{
      AVVideoCodecKey:AVVideoCodecH264,
      // 编解码器
      AVVideoWidthKey:[NSNumber numberWithFloat:320.0f],
      AVVideoHeightKey:[NSNumber numberWithFloat:240.0f],
      AVVideoCompressionPropertiesKey:videoCompressionProps
      // 视频压缩属性
      };
    // 初始化文件写入入口
    self.assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettingsDic];
    
    // 指示  输入是否应该调整(适应)其(实时源)的媒体数据处理。
    // Indicates whether the input should tailor its processing of media data for real-time sources.
    [_assetWriterInput setExpectsMediaDataInRealTime:YES];
    
    // 设置写入视频文件旋转角度
    CGFloat rotationRadians = [self getRotationRadiansForAssetWriterInput];
    [self.assetWriterInput setTransform:CGAffineTransformMakeRotation(rotationRadians)];
#pragma mark -- 为文件写入类添加一个输入源
    // 为文件写入类添加一个输入源
    if ([self.assetWriter canAddInput:self.assetWriterInput]) {
        [self.assetWriter addInput:self.assetWriterInput];
    }
    
    

#pragma mark -- 在时间0开始一个采样写入
    // initiates a sample-writing at time 0
    // 在时间0开始一个采样写入
    self.nextPTS = kCMTimeZero;
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:self.nextPTS];
    
    return YES;
}
/**
 *  根据设备方向返回写入视频文件旋转弧度
 *
 *  @return 旋转弧度
 */
- (CGFloat)getRotationRadiansForAssetWriterInput {
    CGFloat rotationDegrees;// 旋转系数
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationPortraitUpsideDown:
            rotationDegrees = -90.;
            break;
        case UIDeviceOrientationLandscapeLeft: // no rotation
            rotationDegrees = 0.;
            break;
        case UIDeviceOrientationLandscapeRight:
            rotationDegrees = 180.;
            break;
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default:
            rotationDegrees = 90.;
            break;
    }
    CGFloat rotationRadians = DegreesToRadians(rotationDegrees);
    return rotationRadians;
}
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

/**
 *  Called whenever an AVCaptureVideoDataOutput instance outputs a new video frame.
 *  每当AVCaptureVideoDataOutput实例输出一个新的视频帧调用。
 *
 */
// Delegate routine that is called when a sample buffer was written 每秒钟调用30次？
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    LOG(@"AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿");
    if (self.started) {
        // set up the AVAssetWriter using the format description from the first sample buffer captured
#pragma mark -- 使用格式描述从拍摄的第一个样本缓冲区 建立AVAssetWriter
        if ( self.assetWriter == nil ) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
         // 不在成功直接成功return
            if (![self setupAssetWriterForURL:_outputMovURL formatDescription:formatDescription]) {
                LOG(@"setupAssetWriterForURL error");
                return;
            }
        }
        // re-time the sample buffer - in this sample frameDuration is set to 5 fps
        // 原样数据 时序信息
        /**
         *  在一个CMSampleBuffer样本时序信息的收集。
         *  单CMSampleTimingInfo结构可以描述每一个个体样品中的CMSampleBuffer，如果样品都具有相同的持续时间和是在没有间隙呈现顺序。
         */
        CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;// 首先指向一个空的对象
        /**
         *  当前时间
         *  样本的持续时间。
         *  如果单一结构适用于每个样品时，都将有此持续时间。
         */
        timingInfo.duration = self.frameDuration;// 持续时间
        /**
         *  呈现（当前）时间戳
         *  在其中样品将被呈现的时间。
         *  如果单结构适用于各样品，这是其中的presentationTime第一个样本。
         *  后续样品的presentationTime将由衍生反复添加样品的持续时间。
         */
        timingInfo.presentationTimeStamp = self.nextPTS; // 呈现（当前）时间戳
        
        /**
         *  串行数据缓存器
         *  一个CMSampleBuffer的引用，包含CF对象的引用零个或多个压缩（或压缩）特定的媒体类型（音频，视频，多工等）的样品。
         */
        CMSampleBufferRef sbufWithNewTiming = NULL;
        /**
         *  创建副本CMSampleBuffer新的计时信息。
         *
         *  @param kCFAllocatorDefault 分配器用于分配CMSampleBuffer对象。
                                       通过kCFAllocatorDefault使用默认分配器。
         *  @param sampleBuffer        CMSampleBuffer包含原始样本。
         *  @param 1                   在条目数sampleTimingArray。
                                       必须在原sampleBuffer是0，1或NUMSAMPLES
         *  @param timingInfo          数组CMSampleTimingInfo结构，每采样1结构。
                                       如果所有的样品都具有相同的持续时间，并且在呈现顺序，
                                       则可以通过一个单一 CMSampleTimingInfo结构与持续时间设置为一个样本的持续时间presentationTimeStamp 设置为数值最早样品的显现时间，并decodeTimeStamp设为 kCMTimeInvalid。
                                       行为不确定如果在一个样品CMSampleBuffer（或甚至在同一个流中的多个缓冲器）具有相同的presentationTimeStamp。可以是NULL。
         *  @param sbufWithNewTiming   在输出时，指向的新创建的副 ​​本CMSampleBuffer
         *
         *  @return 结果码。见结果代码https://developer.apple.com/reference/coremedia/1669345-cmsamplebuffer#1670024
         */
        OSStatus err = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                                             sampleBuffer,
                                                             1, // numSampleTimingEntries 入口
                                                             &timingInfo,
                                                             &sbufWithNewTiming);
        
        // 判断从另一个样品缓冲使用新的定时信息创建一个CMSampleBuffer。有没有错误
        if (err) {
            LOG(@"CMSampleBufferCreateCopyWithNewTiming error");
            return;
        }
        
#pragma mark -- 开始采样
        // append the sample buffer if we can and increment presnetation time
        // 如果可以追加样品缓冲和增量呈现时间
        if ( [self.assetWriterInput isReadyForMoreMediaData] )
        {
            // 追加SampleBuffer  sbufWithNewTiming在输出时，指向的新创建的副 ​​本CMSampleBuffer
            if ([self.assetWriterInput appendSampleBuffer:sbufWithNewTiming])
            {
                self.nextPTS = CMTimeAdd(self.frameDuration, self.nextPTS);
                
                if ([[self imageFromSampleBuffer:sampleBuffer] isKindOfClass:[UIImage class]]) {
                    LOG(@"采集到图像😊");
                }
            }
            else
            {
                NSError *error = [self.assetWriter error];
                LOG(@"failed to append sbuf: %@", error);
            }
        }
        else
        {
            ShowAlert(@"isReadyForMoreMediaData error");
        }
        
        // release the copy of the sample buffer we made
        CFRelease(sbufWithNewTiming);// 写入采样后释放该对象
        
        self.currentFrame++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat p = (CGFloat)((CGFloat)self.currentFrame / (CGFloat)self.maxFrame);
            [self.progressBar setProgress:p animated:YES];
        });
        
        if (self.currentFrame >= self.maxFrame) {
            [self performSelectorOnMainThread:@selector(stopedForce) withObject:nil waitUntilDone:YES];
        }
    }
}
/**
 *  从原样缓存中获取image
 *
 *  @param sampleBuffer 数据源
 *
 *  @return iamge
 */
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace)
    {
        NSLog(@"CGColorSpaceCreateDeviceRGB failure");
        return nil;
    }
    
    // Get the base address of the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a Quartz direct-access data provider that uses data we supply
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize,
                                                              NULL);
    // Create a bitmap image from data supplied by our data provider
    CGImageRef cgImage =
    CGImageCreate(width,
                  height,
                  8,
                  32,
                  bytesPerRow,
                  colorSpace,
                  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
                  provider,
                  NULL,
                  true,
                  kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    // Create and return an image object representing the specified Quartz image
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;
}

- (void)stopedForce
{
    [self stopRecordBtnClick:nil];
    ShowAlert(@"录制完成");
}


#pragma mark - 初始化一些参数

- (void)initPara {
    static int a = 0;
    a++;
    LOG(@"我被调用了：%d",a);
    self.started = NO;
    self.currentFrame = 0;
    
#pragma mark -- 设置帧率？
    // 24 fps - taking 25 pictures will equal 1 second of video
    self.frameDuration = CMTimeMakeWithSeconds(1.0/20, 9000);

    self.maxFrame = 40*10; // 设置每秒24帖，最长10秒
    
    [self.view bringSubviewToFront:_topBar];
    
    self.outputMovURL = [NSURL fileURLWithPath:[[self documentDir] stringByAppendingPathComponent:@"v.mov"]];
    self.outputMp4URL = [NSURL fileURLWithPath:[[self documentDir] stringByAppendingPathComponent:@"v.mp4"]];
}

#pragma mark - custom UI
#pragma mark -- 初始化一个进度条
/**
 *  初始化一个精度条
 */
- (void)setupProgressBar
{
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressBar.frame = CGRectMake(0.0f, 0.0f, kMainScreenWidth, 44.0f);
    [self.view addSubview:_progressBar];
}

#pragma mark - 视图控制器方法

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 关闭 session
    if (_captureSession) [_captureSession stopRunning];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 开启 session
    if (_captureSession) [_captureSession startRunning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initPara];
    
    [self deleteFile:self.outputMovURL];
    
    [self deleteFile:self.outputMp4URL];
    
    [self setupProgressBar];
    
    [self setupAVCapture];
    
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - private method
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
/**
 *  删除路径下的文件
 *
 *  @param filePath filePath
 */
- (void)deleteFile:(NSURL*)filePath
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    // 是否存在
    BOOL isExistsOk = [fm fileExistsAtPath:[filePath path]];
    
    if (isExistsOk) {
        [fm removeItemAtURL:filePath error:nil];
        LOG(@"file deleted:%@",filePath);
    } else {
        LOG(@"🍎 file not exists:%@",filePath);
    }
}
/**
 *  转化为MP4
 */
- (void)convertToMp4
{
    NSString *_mp4Quality = AVAssetExportPresetMediumQuality;
    
    // 试图删除原mp4
    [self deleteFile:self.outputMp4URL];
    
    // 生成mp4
    /**
     *   调试函数耗时的利器CFAbsoluteTimeGetCurrent
     *
     CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
     // do something
     CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
     NSLog(@"time cost: %0.3f", end - start);
     *
     */
    CFAbsoluteTime s = CFAbsoluteTimeGetCurrent();
    // 初始化视频媒体文件 （使用录制好的Mov文件）
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:self.outputMovURL options:nil];
    // 输出预设（标准样式）
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    // 从这个数组中取
    if ([compatiblePresets containsObject:_mp4Quality]) {
        // 资源输出会话层
        __block AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset presetName:_mp4Quality] ;
        // 输出路径
        exportSession.outputURL = self.outputMp4URL;
        //                exportSession.shouldOptimizeForNetworkUse = _networkOpt;
        // 输出文件格式
        exportSession.outputFileType = AVFileTypeMPEG4;
        // 异步输出
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            // 处理完成后资源输出会话层状态
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed:
                    LOG(@"AVAssetExportSessionStatusFailed（已经失败）:%@",[exportSession error]);
                    break;
                case AVAssetExportSessionStatusCancelled:
                    LOG(@"Export canceled 取消");
                    break;
                case AVAssetExportSessionStatusCompleted:
                {
                    LOG(@"Successful! 完成状态");
                    [self performSelectorOnMainThread:@selector(convertFinish) withObject:nil waitUntilDone:NO];
                    CFAbsoluteTime e = CFAbsoluteTimeGetCurrent();
                    // 转化文件操作消耗的时间
                    LOG(@"转化为MP4文件操作消耗的时间 :%f",e-s);
                }
                    break;
                default:
                    break;
            }
        }];
    } else {
        ShowAlert(@"AVAsset doesn't support mp4 quality");
    }
}
/**
 *  转化格式完成
 */
- (void)convertFinish
{
    ShowAlert(@"convert OK");
}
/**
 *  停止录制视频
 *
 *  @param sender 停止按钮
 */

#pragma mark - 控制按钮点击事件

- (IBAction)backBtnClick:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)playMovBtnClick:(UIBarButtonItem *)sender {
    NSFileManager *fm = [[NSFileManager alloc] init];
    // 是否存在
    BOOL isExistsOk = [fm fileExistsAtPath:[_outputMovURL path]];
    
    if (isExistsOk) {
        MPMoviePlayController *vc = [[MPMoviePlayController alloc]init];
        vc.fileURLPath = _outputMovURL;
        [self presentViewController:vc animated:YES completion:nil];
    }
    else {
        ShowAlert(@"文件不存在");
    }
}

- (IBAction)playMp4BtnClick:(UIBarButtonItem *)sender {
    NSFileManager *fm = [[NSFileManager alloc] init];
    // 是否存在
    BOOL isExistsOk = [fm fileExistsAtPath:[_outputMp4URL path]];
    
    if (isExistsOk) {
        MPMoviePlayController *vc = [[MPMoviePlayController alloc]init];
        vc.fileURLPath = _outputMp4URL;
        [self presentViewController:vc animated:YES completion:nil];
    }
    else {
        ShowAlert(@"文件不存在");
        // 转化为MP4
        [self convertToMp4];
    }
}

- (IBAction)recordBtnClick:(UIBarButtonItem *)sender {
    if (self.started) {
        // 暂停
        [sender setTitle:@"开始录制"];
        self.started = NO;
    } else {
        // 开始
        if (self.currentFrame == 0) {
            // 试图删一下原誩件
            [self deleteFile:_outputMovURL];
            [self deleteFile:_outputMp4URL];
        }
        [sender setTitle:@"暂停录制"];
        // 开始录制
        self.started = YES;
    }
}

- (IBAction)stopRecordBtnClick:(UIBarButtonItem *)sender {
    // 标记为停止录制视频
    _started = NO;
    if (_assetWriter != nil) {
        // 视频写入口标记为已完成
        [_assetWriterInput markAsFinished];
        //
        [_assetWriter finishWritingWithCompletionHandler:^{
            ;
        }];
        // 释放视频写入口
        _assetWriterInput = nil;
        // 释放文件写入类
        _assetWriter = nil;
    }
    _currentFrame = 0;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 
 
 
 
 
 
 
 
 2016-07-01 13:50:01.033 CustomMyCameraDemo01[796:185050] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.075 CustomMyCameraDemo01[796:185050] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.115 CustomMyCameraDemo01[796:185050] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.157 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.199 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.240 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.283 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.324 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.366 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.407 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.449 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.490 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.533 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.573 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.616 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.656 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.699 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.742 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.782 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.824 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.866 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.907 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.949 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 2016-07-01 13:50:01.991 CustomMyCameraDemo01[796:185051] AVCaptureVideoDataOutputSampleBufferDelegate 被调用 👿
 */

@end
