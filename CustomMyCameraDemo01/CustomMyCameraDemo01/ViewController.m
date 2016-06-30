//
//  ViewController.m
//  CustomMyCameraDemo01
//
//  Created by TuSDK on 16/6/29.
//  Copyright © 2016年 TuSDK. All rights reserved.
//

#import "ViewController.h"

#import "MyCameraController.h"

@interface ViewController () {
    BOOL isManualFocus;
    BOOL isPreviewImg;
}

@end

@implementation ViewController
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = NO;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)switchFocusMode:(UISwitch *)sender {
    isManualFocus = sender.on;
    isPreviewImg = sender.on;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)gotoCamera:(UIBarButtonItem *)sender {
    
}
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"camera"]) {
        MyCameraController *cameraController = segue.destinationViewController;
        cameraController.isManualFocus = isManualFocus;
        cameraController.isPreviewImg = isPreviewImg;
    }
}

@end
