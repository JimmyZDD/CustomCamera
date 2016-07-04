//
//  MPMoviePlayController.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/7/1.
//  Copyright © 2016年 TuSDK. All rights reserved.
//
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

#import "MPMoviePlayController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <Availability.h>

@interface MPMoviePlayController ()

/**
 *  MoviePlay
 */
@property (nonatomic, retain) MPMoviePlayerController *player;

@end

@implementation MPMoviePlayController

#pragma mark -- 初始化一个播放器

- (void)setupMoviePlayer {
    MPMoviePlayerController *player = [[MPMoviePlayerController alloc]initWithContentURL:_fileURLPath];
    player.controlStyle = MPMovieControlStyleDefault;
    [player prepareToPlay];
    player.view.frame = self.view.bounds;
    [self.view addSubview:player.view];
    player.shouldAutoplay = YES;
    self.player = player;
}

#pragma mark -- 为播放器添加一些通知

- (void)addSameNotificationForMoviePlayer {
    // 视频播放完成
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:_player];
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readyForDisplay:) name:MPMoviePlayerReadyForDisplayDidChangeNotification object:_player];
}

#pragma mark -- 播放器通知回调事件

- (void)didFinish:(NSNotificationCenter *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)readyForDisplay:(NSNotificationCenter *)sender {
    LOG(@"准备开始播放");
}


#pragma mark -- 控制器视图方法

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupMoviePlayer];
}

- (void)viewWillAppear:(BOOL)animated {
    [self addSameNotificationForMoviePlayer];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
