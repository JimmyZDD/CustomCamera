//
//  MyCameraController.h
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/6/29.
//  Copyright © 2016年 TuSDK. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MyCameraController : UIViewController

/**
 *  是否开启脸部追踪 (默认为NO)
 */
@property (nonatomic, assign) BOOL canFaceRecognition;

/**
 *  是否开启手动对焦 （默认自动）
 */
@property (nonatomic, assign) BOOL isManualFocus;

@end
