//
//  ViewController.m
//  XJAVPlayer
//
//  Created by xj_love on 16/9/1.
//  Copyright © 2016年 Xander. All rights reserved.
//

#import "ViewController.h"
#import "XJAVPlayer.h"
// 屏幕的宽
#define kScreenWidth                         [[UIScreen mainScreen] bounds].size.width
// 屏幕的高
#define kScreenHeight                        [[UIScreen mainScreen] bounds].size.height
@interface ViewController ()<XJAVPlayerDeleagte>{
    XJAVPlayer *myPlayer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    myPlayer = [[XJAVPlayer alloc] initWithFrame:CGRectMake(0, 200, kScreenWidth, kScreenWidth * 0.5)];
    myPlayer.xjPlayerUrl = @"http://cloudisk.vjsp.online/fget?param=%7B%22send_partner%22%3A%2200001%22%2C%22Device%22%3A%22ios%22%2C%22crmGlobalCode%22%3A%22VJSPDEMO2_DISK%22%2C%22data%22%3A%7B%22size%22%3A%2238192202%22%2C%22range%22%3A%22bytes%200-38192202%2F38192202%22%2C%22timestamp%22%3A%221497426261%22%2C%22hash_type%22%3A%22MD5%22%2C%22file_hash%22%3A%22F1357A939458993071FC0EE0A8A484C9%22%2C%22filetoken%22%3A%22RjEzNTdBOTM5NDU4OTkzMDcxRkMwRUUwQThBNDg0QzkuMzgxOTIyMDIuMTQ5NzQxOTU5ODUzMQ_s_s%22%7D%2C%22AppVersion%22%3A%22v0.9%22%2C%22syscode%22%3A%22vjspmoboa%22%2C%22send_sitecharset%22%3A%22utf-8%22%2C%22token%22%3A%22C02PbX0FI0FfHM51XV65X3cOI40F5h4c1g6amn9ZP01KHeCPo4c20F89TW0F21tSWTmzt0FNC39bmdTt4A2ITpSGK52GPrTNGELWnrKmmNRsGnLYfHBLrc0Fs1tSWyAO6zcLqL8TIeX8HiA6X9wPcK70FmvuTce6UHToO6vaJKedCGfNM5qKVsV01Kbp01KKt01a9OQQ196G24JC58sV2OIVXi60F7SA271pSmG1VW9zTd0F80Fte1TG0F2SNO61t46SW5q2N9oSNuDSm1z5427R%22%2C%22send_signmsg%22%3A%222ba290d6bbc3800e66a557b212a8673a%22%2C%22send_sitebh%22%3A%22ec%22%7D&crmGlobalCode=111111";
    myPlayer.delegate = self;
//    <#title#>
    myPlayer.title = @"23";
    [self.view addSubview:myPlayer];//(看自动缩小就把它注释了)

}

#pragma mark - delegate
- (void)changeBackGround{
    if (self.view.backgroundColor == [UIColor whiteColor]) {
        self.view.backgroundColor = [UIColor blackColor];
    }else{
        self.view.backgroundColor = [UIColor whiteColor];
    }
    [self.view reloadInputViews];
}
- (void)backView{
    //push回去
    [myPlayer pause];
    
}

@end
