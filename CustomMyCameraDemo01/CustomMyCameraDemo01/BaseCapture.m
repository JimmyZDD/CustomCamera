//
//  BaseCapture.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/7/1.
//  Copyright © 2016年 TuSDK. All rights reserved.
//

#import "BaseCapture.h"
#import <AVFoundation/AVFoundation.h>

@implementation BaseCapture

/*
 检查是否有相机权限
 */
+ (BOOL)checkAuthority
{
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        return NO;
    }
    return YES;
}
/**
 *  查找摄像头连接设备
 *
 *  @return
 */
- (AVCaptureConnection *)findVideoConnection
{
    /**
     *  一个图片输出的实例
     */
    AVCaptureStillImageOutput *stillImageOutput;
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections) {
        /**
         *  一个AVCaptureInputPort描述由AVCaptureInput提供媒体数据的单个流，并且提供了一种
         接口，用于连接该流通过AVCaptureConnection到AVCaptureOutput实例。
         */
        for (AVCaptureInputPort *port in connection.inputPorts) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        // 找到后就返回
        if (videoConnection) {
            break;
        }
    }
    return videoConnection;
}


@end
