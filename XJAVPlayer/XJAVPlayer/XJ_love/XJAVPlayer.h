//
//  XJAVPlayer.h
//  XJAVPlayer
//
//  Created by xj_love on 16/9/1.
//  Copyright © 2016年 Xander. All rights reserved.
//

#import <UIKit/UIKit.h>
@class XJGestureButton;

@protocol XJAVPlayerDeleagte <NSObject>
//改变背景（关灯）
- (void)changeBackGround;
//返回
- (void)backView;
@end


@interface XJAVPlayer : UIView

@property (nonatomic, assign) id <XJAVPlayerDeleagte>delegate;
#pragma mark - **************************** 外部接口 *************************************
/**
 *  视屏链接
 */
@property (nonatomic, strong) NSString *xjPlayerUrl;
/**
 *  暂停
 */
- (void)pause;
/**
 *  开始
 */
- (void)play;
/**
 * 定位视频播放时间(根据上次存储的时间来定位播放)
 *
 * @param seconds 秒
 *
 *
 */
- (void)seekToTimeWithSeconds:(Float64)seconds;
/**
 * 取得当前播放时间
 *
 */
- (Float64)currentTime;
/**
 * 取得媒体总时长
 *
 */
- (Float64)totalTime;
@property(nonatomic, strong)NSString *title;
#pragma mark - **************************** 自由选择 *************************************
/**
 *  如果想自己写底部菜单，可以移除我写好的菜单；然后通过接口和代理来控制视屏；
 */
- (void)removeXJPlayerBottomMenu;
/**
 *  如果自己添加菜单，建议添加到这个button上；
 */
@property (strong, nonatomic) XJGestureButton *xjGestureButton;
/**
 *  添加,视屏view位置超出屏幕时，位置移到右下角；（慎用）
 */
- (void)addXJPlayerAutoMovie;
/**
 *  如果使用了addXJPlayerAutoMovie，就可以获得view最开始的位置
 */
@property (nonatomic, assign) CGRect originalFrame;//初始位置
/**
 *  移到最开始的位置
 */
- (void)movieXJPlayeToOriginalPosition;

@end
