//
//  XJAVPlayer.m
//  XJAVPlayer
//
//  Created by xj_love on 16/9/1.
//  Copyright © 2016年 Xander. All rights reserved.
//

#import "XJAVPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "UIView+SCYCategory.h"
#import "UIDevice+XJDevice.h"
#import "XJGestureButton.h"
#import "TBloaderURLConnection.h"
#import "TBVideoRequestTask.h"
#import "RightBtn.h"
// 屏幕的宽
#define kScreenWidth                         [[UIScreen mainScreen] bounds].size.width
#define WS(weakSelf) __unsafe_unretained __typeof(&*self)weakSelf = self;
#define IOS_VERSION  ([[[UIDevice currentDevice] systemVersion] floatValue])
#define DownloadPath [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

typedef NS_ENUM(NSUInteger, Direction) {
    DirectionLeftOrRight,
    DirectionUpOrDown,
    DirectionNone
};

@interface XJAVPlayer ()<XJGestureButtonDelegate,TBloaderURLConnectionDelegate>{
    UITapGestureRecognizer *tap;
    BOOL isAutoMovie;//是否开启自动缩到右下角
    BOOL isSmall;//判断是否在右下角
    BOOL isHiden;//底部菜单是否收起
    BOOL isPlay;//是否播放
    BOOL isFull;//是否全屏
    BOOL isFirst;//是否第一次加载
    BOOL isAutoOrient;//自动旋转（不是用放大按钮）
    BOOL isFinishLoad; //是否下载完毕
    CGRect xjPlayerFrame;//初始化的视屏大小
}
@property (nonatomic, strong) UIView *topMenuView;//头部信息
@property (nonatomic, strong) UIView *bottomMenuView;//底部菜单
@property (nonatomic, strong) UIView *rightMenuView;//右侧菜单

@property (nonatomic, strong) UIButton *playOrPauseBtn;//开始/暂停按钮
@property (nonatomic, strong) UIButton *nextPlayerBtn;//下一个视屏（全屏时有）
@property (nonatomic, strong) UIProgressView *loadProgressView;//缓冲进度条
@property (nonatomic, strong) UISlider *playSlider;//播放滑动条
@property (nonatomic, strong) UIButton *fullOrSmallBtn;//放大/缩小按钮
@property (nonatomic, strong) UILabel *topTitle;//头部标题
/** 当前时间 */
@property (nonatomic, strong) UILabel *currentLabel;
/** 总时间 */
@property (nonatomic, strong) UILabel *totalLabel;
//@property (nonatomic, strong) UILabel *timeLabel; //时间标签
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;//菊花图

@property (nonatomic, strong) AVPlayer *xjPlayer;
@property (nonatomic, strong) AVPlayerItem *xjPlayerItem;
@property (nonatomic, strong) AVURLAsset     *videoURLAsset;
@property (nonatomic, strong) AVAsset        *videoAsset;

@property (nonatomic, strong) id playbackTimeObserver;//界面更新时间ID
@property (nonatomic, strong) NSString *avTotalTime;//视屏时间总长；
//上下左右手势操作
@property (assign, nonatomic) Direction direction;
@property (assign, nonatomic) CGPoint startPoint;//手势触摸起始位置
@property (assign, nonatomic) CGFloat startVB;//记录当前音量/亮度
@property (assign, nonatomic) CGFloat startVideoRate;//开始进度
@property (strong, nonatomic) CADisplayLink *link;//以屏幕刷新率进行定时操作
@property (assign, nonatomic) NSTimeInterval lastTime;
@property (strong, nonatomic) MPVolumeView *volumeView;//控制音量的view
@property (strong, nonatomic) UISlider *volumeViewSlider;//控制音量
@property (assign, nonatomic) CGFloat currentRate;//当期视频播放的进度
//缓存
@property (nonatomic, strong) TBloaderURLConnection *resouerLoader;
@property (nonatomic, strong) NSURL *filePath;//缓存地址
@property (nonatomic, strong) NSString *savePath;
//关闭
@property (nonatomic, strong) UIButton *closeBtn;
//信息
@property (nonatomic, strong) UIButton *infoBtn;
@end

@implementation XJAVPlayer

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer*)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)p {
    [(AVPlayerLayer *)[self layer] setPlayer:p];
}

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor blackColor];
        [self setUserInteractionEnabled:NO];
        
        xjPlayerFrame = frame;
        self.originalFrame = frame;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xjPlayerEndPlay:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.xjPlayerItem];//注册监听，视屏播放完成
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientChange:) name:UIDeviceOrientationDidChangeNotification object:nil];//注册监听，屏幕方向改变
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

#pragma mark - 初始化播放器
- (void)xjPlayerInit{
    //限制锁屏
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    
    if (self.xjPlayer) {
        self.xjPlayer = nil;
    }
    
    //如果是ios  < 7 或者是本地资源，直接播放
    if ([self fileExistsAtPath:self.xjPlayerUrl]) {
        
        self.videoAsset = [AVURLAsset URLAssetWithURL:self.filePath options:nil];
        self.xjPlayerItem = [AVPlayerItem playerItemWithAsset:_videoAsset];
        self.xjPlayer = [AVPlayer playerWithPlayerItem:self.xjPlayerItem];
        [self setPlayer:self.xjPlayer];
        
    }else{
        
        self.resouerLoader = [[TBloaderURLConnection alloc] init];
        self.resouerLoader.delegate = self;
        self.resouerLoader.savePath = self.savePath;
        NSURL *playUrl = [_resouerLoader getSchemeVideoURL:[NSURL URLWithString:self.xjPlayerUrl]];
        self.videoURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
        [_videoURLAsset.resourceLoader setDelegate:_resouerLoader queue:dispatch_get_main_queue()];
        self.xjPlayerItem = [AVPlayerItem playerItemWithAsset:_videoURLAsset];
        
        self.xjPlayer = [AVPlayer playerWithPlayerItem:self.xjPlayerItem];
        [self setPlayer:self.xjPlayer];
    }
    
    [self.xjPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];//监听status属性变化
    [self.xjPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];//见天loadedTimeRanges属性变化
}

#pragma mark - 添加控件
- (void)addToolView{
    
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(upadte)];//和屏幕频率刷新相同的定时器
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.xjGestureButton addSubview:self.bottomMenuView];
    [self.xjGestureButton addSubview:self.topMenuView];
    [self.xjGestureButton addSubview:self.rightMenuView];
    //初始化 懒加载 只创建一次默认是竖屏所以是宽度
//    NSInteger btnW = (self.width - 200) / 3;
    NSArray *titleA = @[@"下载",@"分享",@"删除"];
    for (int i = 0; i<3; i++) {
#warning : 需要改布局
        RightBtn *btn = [[RightBtn alloc] init];
        btn.frame = CGRectMake(0, 60 * i + (self.width - 300)/2, 60, 60);
        [btn setTitle:titleA[i] forState:UIControlStateNormal];
        [self.rightMenuView addSubview:btn];
    }
    [self.topMenuView addSubview:self.closeBtn];
    [self.topMenuView addSubview:self.infoBtn];
   
    [self.topMenuView addSubview:self.topTitle];
    
    UITapGestureRecognizer *topNilTap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    topNilTap.cancelsTouchesInView = NO;
    
    [self.topMenuView addGestureRecognizer:topNilTap];
    
    UITapGestureRecognizer *nilTap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    nilTap.cancelsTouchesInView = NO;

    [self.bottomMenuView addGestureRecognizer:nilTap];//防止bottomMenuView也响应了self这个view的单击手势
    [self addSubview:self.xjGestureButton];
    [self.bottomMenuView addSubview:self.playOrPauseBtn];
    [self.bottomMenuView addSubview:self.fullOrSmallBtn];
    
    [self.bottomMenuView addSubview:self.currentLabel];
    [self.bottomMenuView addSubview:self.totalLabel];
    [self.bottomMenuView addSubview:self.loadProgressView];
    [self.bottomMenuView addSubview:self.playSlider];
    [self.xjGestureButton addSubview:self.loadingView];
}

#pragma mark - 控件事件
//开始/暂停视频播放
- (void)playOrPauseAction{
    if (!isPlay) {
        [self.xjPlayer play];
        isPlay = YES;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];

    }else{
        [self.xjPlayer pause];
        isPlay = NO;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
 
    }
}

//放大/缩小视图
- (void)fullOrSmallAction{
    if (isFull) {
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationPortrait];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        self.frame = xjPlayerFrame;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
    }else{
        [UIView animateWithDuration:3 animations:^{
            self.bottomMenuView.alpha = 0;
            self.topMenuView.alpha = 0;
            self.rightMenuView.alpha = 0;
        }];
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationLandscapeRight];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        self.frame = self.window.bounds;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
        isFull = YES;
    }
}
//slider拖动时
- (void)playSliderValueChanging:(id)sender{
    WS(weakSelf);
    UISlider *slider = (UISlider*)sender;
    [self.xjPlayer pause];
    [self.loadingView startAnimating];//缓冲没好时加上网络不佳，拖动后会加载网络
    if (slider.value == 0.0000) {
        [self.xjPlayer seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
            [weakSelf.xjPlayer play];
            [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
            isPlay = YES;
        }];
    }
}
//slider完成拖动时
- (void)playSliderValueDidChanged:(id)sender{
    WS(weakSelf);
    UISlider *slider = (UISlider*)sender;
    CMTime changeTime = CMTimeMakeWithSeconds(slider.value,NSEC_PER_SEC);
    [self.xjPlayer seekToTime:changeTime completionHandler:^(BOOL finished) {
        [weakSelf.xjPlayer play];
        [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        isPlay = YES;
    }];
}

#pragma mark - 监听事件
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            
            NSLog(@"播放成功");
            [self.loadingView stopAnimating];
            [self setUserInteractionEnabled:YES];//成功才能弹出底部菜单
            
            CMTime duration = self.xjPlayerItem.duration;//获取视屏总长
            CGFloat totalSecond = playerItem.duration.value/playerItem.duration.timescale;//转换成秒
            
            self.playSlider.maximumValue = CMTimeGetSeconds(duration);//设置slider的最大值就是总时长
            self.avTotalTime = [self xjPlayerTimeStyle:totalSecond];//获取视屏总长及样式
            [self monitoringXjPlayerBack:playerItem];//监听播放状态
            
        }else if (playerItem.status == AVPlayerItemStatusUnknown){
            NSLog(@"播放未知");
        }else if (playerItem.status == AVPlayerStatusFailed){
            NSLog(@"播放失败");
        }
    }else if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        
        NSTimeInterval timeInterval = [self xjPlayerAvailableDuration];
        CMTime duration = self.xjPlayerItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        [self.loadProgressView setProgress:timeInterval/totalDuration animated:YES];
        
    }
    
}
//视屏播放完后的通知事件。从头开始播放；
- (void)xjPlayerEndPlay:(NSNotification*)notification{
    WS(weakSelf);
    [self.xjPlayer seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [weakSelf.playSlider setValue:0.0 animated:YES];
        [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        isPlay = NO;
    }];
}

//刷新，看播放是否卡顿
- (void)upadte
{
    NSTimeInterval current = CMTimeGetSeconds(self.xjPlayer.currentTime);
    if (current!=self.lastTime) {
        //没有卡顿
        if (isPlay) {
            [self.xjPlayer play];
        }
        [self.loadingView stopAnimating];
    }else{
        if (!isPlay) {
            [self.loadingView stopAnimating];
            return;
        }else{
            [self.loadingView startAnimating];
        }
    }
    self.lastTime = current;
}

//程序进入后台（如果播放，则暂停，否则不管）
- (void)appDidEnterBackground{
    if (isPlay) {
        [self.xjPlayer pause];
        [self.xjPlayer removeTimeObserver:self.playbackTimeObserver];
    }
}
//程序进入前台（退出前播放，进来后继续播放，否则不管）
- (void)appDidEnterPlayGround{
    if (isPlay) {
        [self.xjPlayer play];
        [self monitoringXjPlayerBack:self.xjPlayer.currentItem];
    }
}
#pragma mark - 屏幕方向改变的监听
//屏幕方向改变时的监听
- (void)orientChange:(NSNotification *)notification{
    UIDeviceOrientation orient = [[UIDevice currentDevice] orientation];
    switch (orient) {
            isAutoOrient = YES;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        {
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            self.frame = xjPlayerFrame;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
            isFull = NO;
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeLeft:      // Device oriented horizontally, home button on the right
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            [self layoutSubviews];
        }
            break;
        default:
            break;
    }
}
#pragma mark - 自定义事件
//定义视屏时长样式
- (NSString *)xjPlayerTimeStyle:(CGFloat)time{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (time/3600>1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    }else{
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showTimeStyle = [formatter stringFromDate:date];
    return showTimeStyle;
}
//实时监听播放状态
- (void)monitoringXjPlayerBack:(AVPlayerItem *)playerItem{
    //一秒监听一次CMTimeMake(a, b),a/b表示多少秒一次；
    WS(weakSelf);
    self.playbackTimeObserver = [self.xjPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        [weakSelf.loadingView stopAnimating];
        CGFloat currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;//获取当前时间
        [weakSelf.playSlider setValue:currentSecond animated:YES];
        
        if (!weakSelf->isFull&&weakSelf->isAutoMovie) {
            CGRect rect = [weakSelf.window convertRect:weakSelf.frame fromView:weakSelf.superview];
            
            if (rect.origin.y+(weakSelf.frame.size.height*0.5) <= 0) {//当前XJPlayerView移除到屏幕外一半时，就缩到左下角
                [weakSelf bottomRightXJPlayer];
            }
        }
        
        NSString *timeString = [weakSelf xjPlayerTimeStyle:currentSecond];
        weakSelf.currentLabel.text = timeString;
        weakSelf.totalLabel.text = weakSelf.avTotalTime;
//        weakSelf.timeLabel.text = [NSString stringWithFormat:@"00:%@/00:%@",timeString,weakSelf.avTotalTime];
    }];
}

//移到右下角
- (void)bottomRightXJPlayer{
    self.frame = CGRectMake(self.window.right-160, self.window.height-150, 150, 100);
    isSmall = YES;
    [self.superview.superview addSubview:self];
    [self.superview.superview bringSubviewToFront:self];
    
    if (!isHiden) {
        self.bottomMenuView.hidden = YES;
    }
    tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    tap.cancelsTouchesInView = NO;
    [self.xjGestureButton addGestureRecognizer:tap];
    //    self.xjGestureButton.hidden = YES;
}

- (void)movieXJPlayeToOriginalPosition{
    if (!isFull) {
        self.frame = xjPlayerFrame;
        isSmall = NO;
    }
    
    if (!isHiden) {
        self.bottomMenuView.hidden = NO;
    }
    
    [self.xjGestureButton removeGestureRecognizer:tap];
    //    self.xjGestureButton.hidden = NO;
}
//计算缓冲区
- (NSTimeInterval)xjPlayerAvailableDuration{
    NSArray *loadedTimeRanges = [[self.xjPlayer currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];//获取缓冲区域
    CGFloat startSeconds = CMTimeGetSeconds(timeRange.start);
    CGFloat durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds+durationSeconds;//计算缓冲进度
    return result;
}
//判断是否存在已下载好的文件
- (BOOL)fileExistsAtPath:(NSString *)url{
    
    self.savePath = [[self.xjPlayerUrl componentsSeparatedByString:@"/"] lastObject];//保存文件名是地址最后“/”后面的字符串
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tempPath = DownloadPath;
    NSString *str = [tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"xjPlayer/%@",self.savePath]];
    
    if ([fileManager fileExistsAtPath:str]) {
        self.filePath = [NSURL fileURLWithPath:str];
        NSLog(@"filePath:%@",str);
        return YES;
    }else{
        NSLog(@"没有缓存");
        return NO;
    }
    
}

#pragma mark - 自定义Button的代理***********************************************************
#pragma mark - 开始触摸
/*************************************************************************/
- (void)touchesBeganWithPoint:(CGPoint)point {
    //记录首次触摸坐标
    self.startPoint = point;
    //检测用户是触摸屏幕的左边还是右边，以此判断用户是要调节音量还是亮度，左边是音量，右边是亮度
    if (self.startPoint.x <= self.xjGestureButton.frame.size.width / 2.0) {
        //音/量
        self.startVB = self.volumeViewSlider.value;
    } else {
        //亮度
        self.startVB = [UIScreen mainScreen].brightness;
    }
    //方向置为无
    self.direction = DirectionNone;
    //记录当前视频播放的进度
    CMTime ctime = self.xjPlayer.currentTime;
    self.startVideoRate = ctime.value / ctime.timescale / CMTimeGetSeconds(self.xjPlayer.currentItem.duration);;
    
}

#pragma mark - 结束触摸
- (void)touchesEndWithPoint:(CGPoint)point {
    if (self.direction == DirectionLeftOrRight&&!isSmall) {
        [self.xjPlayer seekToTime:CMTimeMakeWithSeconds(CMTimeGetSeconds(self.xjPlayer.currentItem.duration) * self.currentRate, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
            //在这里处理进度设置成功后的事情
        }];
    }
}

#pragma mark - 拖动
- (void)touchesMoveWithPoint:(CGPoint)point {
    //得出手指在Button上移动的距离
    CGPoint panPoint = CGPointMake(point.x - self.startPoint.x, point.y - self.startPoint.y);
    
    if (isSmall) {
        // Calculate offset
        float dx = point.x - self.startPoint.x;
        float dy = point.y - self.startPoint.y;
        CGPoint newcenter = CGPointMake(self.center.x + dx, self.center.y + dy);
        
        //设置移动区域
        // Bound movement into parent bounds
        float halfx = CGRectGetMidX(self.bounds);
        newcenter.x = MAX(halfx, newcenter.x);
        newcenter.x = MIN(self.superview.bounds.size.width - halfx, newcenter.x);
        
        float halfy = CGRectGetMidY(self.bounds);
        newcenter.y = MAX(halfy, newcenter.y);
        newcenter.y = MIN(self.superview.bounds.size.height - halfy, newcenter.y);
        
        // Set new location
        self.center = newcenter;
    }
    
    //分析出用户滑动的方向
    if (self.direction == DirectionNone) {
        if (panPoint.x >= 30 || panPoint.x <= -30) {
            //进度
            self.direction = DirectionLeftOrRight;
        } else if (panPoint.y >= 30 || panPoint.y <= -30) {
            //音量和亮度
            self.direction = DirectionUpOrDown;
        }
    }
    
    if (self.direction == DirectionNone) {
        return;
    } else if (self.direction == DirectionUpOrDown&&!isSmall) {
        //音量和亮度
        if (self.startPoint.x <= self.xjGestureButton.frame.size.width / 2.0) {
            //音量
            if (panPoint.y < 0) {
                //增大音量
                [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                if (self.startVB + (-panPoint.y / 30 / 10) - self.volumeViewSlider.value >= 0.1) {
                    [self.volumeViewSlider setValue:0.1 animated:NO];
                    [self.volumeViewSlider setValue:self.startVB + (-panPoint.y / 30.0 / 10) animated:YES];
                }
                
            } else {
                //减少音量
                [self.volumeViewSlider setValue:self.startVB - (panPoint.y / 30.0 / 10) animated:YES];
            }
            
        } else if(!isSmall){
            
            //调节亮度
            if (panPoint.y < 0) {
                //增加亮度
                [[UIScreen mainScreen] setBrightness:self.startVB + (-panPoint.y / 30.0 / 10)];
            } else {
                //减少亮度
                [[UIScreen mainScreen] setBrightness:self.startVB - (panPoint.y / 30.0 / 10)];
            }
        }
    } else if (self.direction == DirectionLeftOrRight &&!isSmall) {
        //进度
        CGFloat rate = self.startVideoRate + (panPoint.x / 30.0 / 20.0);
        if (rate > 1) {
            rate = 1;
        } else if (rate < 0) {
            rate = 0;
        }
        self.currentRate = rate;
    }
}

- (void)userTapGestureAction:(UITapGestureRecognizer *)xjTap{
    if (xjTap.numberOfTapsRequired == 1) {
        if (isFull) {
            if (self.bottomMenuView.alpha == 0) {
                [UIView animateWithDuration:1 animations:^{
                    self.bottomMenuView.alpha = 1;
                    self.topMenuView.alpha = 1;
                    self.rightMenuView.alpha = 1;
                }];
            }else{
                [UIView animateWithDuration:1 animations:^{
                    self.bottomMenuView.alpha = 0;
                    self.topMenuView.alpha = 0;
                    self.rightMenuView.alpha = 0;
                }];
                
            }
            
        }else{
            //开/关灯
            [self.delegate changeBackGround];
        }

    }else if (xjTap.numberOfTapsRequired == 2){
        [self playOrPauseAction];
    }
}


#pragma mark - TBloaderURLConnectionDelegate

- (void)didFinishLoadingWithTask:(TBVideoRequestTask *)task
{
    isFinishLoad = task.isFinishLoad;
}

//网络中断：-1005
//无网络连接：-1009
//请求超时：-1001
//服务器内部错误：-1004
//找不到服务器：-1003
- (void)didFailLoadingWithTask:(TBVideoRequestTask *)task WithError:(NSInteger)errorCode
{
    NSString *str = nil;
    switch (errorCode) {
        case -1001:
            str = @"请求超时";
            break;
        case -1003:
        case -1004:
            str = @"服务器错误";
            break;
        case -1005:
            str = @"网络中断";
            break;
        case -1009:
            str = @"无网络连接";
            break;
            
        default:
            str = [NSString stringWithFormat:@"%@", @"(_errorCode)"];
            break;
    }
    NSLog(@"%@",str);
    
}

#pragma mark - 外部接口
/**
 *  如果想自己写底部菜单，可以移除我写好的菜单；然后通过接口和代理来控制视屏;
 */
- (void)removeXJPlayerBottomMenu{
    [self.bottomMenuView removeFromSuperview];
}
- (void)addXJPlayerAutoMovie{
    isAutoMovie = YES;
}
/**
 *  暂停
 */
- (void)pause{
    [self playOrPauseAction];
}
/**
 *  开始
 */
- (void)play{
    [self playOrPauseAction];
}
/**
 * 定位视频播放时间
 *
 * @param seconds 秒
 *
 *
 */
- (void)seekToTimeWithSeconds:(Float64)seconds {
    [self.xjPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC )];
}
/**
 * 取得当前播放时间
 *
 */
- (Float64)currentTime {
    return CMTimeGetSeconds([self.xjPlayer currentTime]);
}
/**
 * 取得媒体总时长
 *
 */
- (Float64)totalTime {
    return CMTimeGetSeconds(self.xjPlayerItem.duration );
}
- (void)setTitle:(NSString *)title{
    _title = title;
    self.topTitle.text = self.title;
}
#pragma mark - 懒加载
- (void)setXjPlayerUrl:(NSString *)xjPlayerUrl{
    _xjPlayerUrl = xjPlayerUrl;
    if (isFirst) {
        if (isPlay) {
            [self.xjPlayer pause];
            [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
            isPlay = NO;
        }
        [self setUserInteractionEnabled:NO];
        [self.loadingView startAnimating];
    }
    [self xjPlayerInit];
    if (!isFirst) {
        [self addToolView];
        isFirst = YES;
    }
}

- (UIView *)bottomMenuView{
    if (_bottomMenuView == nil) {
        _bottomMenuView = [[UIView alloc] init];
        _bottomMenuView.backgroundColor = [UIColor colorWithRed:50.0/255.0 green:50.0/255.0 blue:50.0/255.0 alpha:1.0];
//        _bottomMenuView.hidden = YES;
        isHiden = YES;
    }
    return _bottomMenuView;
}

- (UIButton *)playOrPauseBtn{
    if (_playOrPauseBtn == nil) {
        _playOrPauseBtn = [[UIButton alloc] init];
        [_playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        [_playOrPauseBtn addTarget:self action:@selector(playOrPauseAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playOrPauseBtn;
}



- (UIButton *)fullOrSmallBtn{
    if (_fullOrSmallBtn == nil) {
        _fullOrSmallBtn = [[UIButton alloc] init];
        [_fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
        [_fullOrSmallBtn addTarget:self action:@selector(fullOrSmallAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fullOrSmallBtn;
}

- (UILabel *)currentLabel{
    if (_currentLabel == nil) {
        _currentLabel = [[UILabel alloc] init];
        _currentLabel.textColor = [UIColor whiteColor];
        _currentLabel.font = [UIFont systemFontOfSize:11.0];
        _currentLabel.textAlignment = NSTextAlignmentCenter;
        _currentLabel.text = @"00:00";
    }
    return _currentLabel;
}

- (UILabel *)totalLabel{
    if (_totalLabel == nil) {
        _totalLabel = [[UILabel alloc] init];
        _totalLabel.textColor = [UIColor whiteColor];
        _totalLabel.font = [UIFont systemFontOfSize:11.0];
        _totalLabel.textAlignment = NSTextAlignmentCenter;
        _totalLabel.text = @"00:00";
    }
    return _totalLabel;
}
- (UIProgressView *)loadProgressView{
    if (_loadProgressView == nil) {
        _loadProgressView = [[UIProgressView alloc] init];
    }
    return _loadProgressView;
}

- (UISlider *)playSlider{
    if (_playSlider == nil) {
        _playSlider = [[UISlider alloc] init];
        _playSlider.minimumValue = 0.0;
        
        UIGraphicsBeginImageContextWithOptions((CGSize){1,1}, NO, 0.0f);
        UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self.playSlider setThumbImage:[UIImage imageNamed:@"icon_progress"] forState:UIControlStateNormal];
        [self.playSlider setMinimumTrackImage:transparentImage forState:UIControlStateNormal];
        [self.playSlider setMaximumTrackImage:transparentImage forState:UIControlStateNormal];
        
        [_playSlider addTarget:self action:@selector(playSliderValueChanging:) forControlEvents:UIControlEventValueChanged];
        [_playSlider addTarget:self action:@selector(playSliderValueDidChanged:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playSlider;
}

- (UIActivityIndicatorView *)loadingView{
    if (_loadingView == nil) {
        _loadingView = [[UIActivityIndicatorView alloc] init];
        [_loadingView startAnimating];
    }
    return _loadingView;
}
- (UIView*)topMenuView{
    if (_topMenuView==nil) {
        _topMenuView = [[UIView alloc] init];
        _topMenuView.backgroundColor = [UIColor colorWithRed:50.0/255.0 green:50.0/255.0 blue:50.0/255.0 alpha:1.0];
//        _topMenuView.hidden = YES;
    }
    return _topMenuView;
}
- (UIView *)rightMenuView{
    if (_rightMenuView==nil) {
        _rightMenuView = [[UIView alloc] init];
        _rightMenuView.backgroundColor = [UIColor clearColor];
    }
    return _rightMenuView;
}
- (UILabel *)topTitle{
    if (_topTitle == nil) {
        _topTitle = [[UILabel alloc] init];
        _topTitle.textColor = [UIColor whiteColor];
        _topTitle.font = [UIFont boldSystemFontOfSize:18];
        _topTitle.textAlignment = NSTextAlignmentCenter;
        _topTitle.text = @"";
    }
    return _topTitle;
}
- (UIButton *)closeBtn{
    if (_closeBtn == nil) {
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        NSMutableAttributedString* closeStr = [[NSMutableAttributedString alloc] initWithString:@"关闭"];
        [closeStr addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:(NSRange){0,[closeStr length]}];
        [closeStr addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor]  range:NSMakeRange(0,[closeStr length])];
        [_closeBtn setAttributedTitle:closeStr forState:UIControlStateNormal];
        [self.closeBtn addTarget:self action:@selector(closeClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeBtn;
    
}

- (UIButton *)infoBtn{
    if (_infoBtn == nil) {
        _infoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_infoBtn setTitle:@"..." forState:UIControlStateNormal];
        [_infoBtn addTarget:self action:@selector(infoClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _infoBtn;
    
}
- (MPVolumeView *)volumeView {
    if (_volumeView == nil) {
        _volumeView  = [[MPVolumeView alloc] init];
        [_volumeView sizeToFit];
        for (UIView *view in [_volumeView subviews]){
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
                self.volumeViewSlider = (UISlider*)view;
                break;
            }
        }
    }
    return _volumeView;
}

- (XJGestureButton *)xjGestureButton{
    if (_xjGestureButton == nil) {
        //添加自定义的Button到视频画面上
        _xjGestureButton = [[XJGestureButton alloc] initWithFrame:xjPlayerFrame];
        _xjGestureButton.tag = 1000;
        _xjGestureButton.touchDelegate = self;
    }
    return _xjGestureButton;
}

//布局
- (void)layoutSubviews{
    
    self.topMenuView.frame= CGRectMake(0, 0, self.width, 40);
    self.topTitle.frame = CGRectMake(70, 10, kScreenWidth - 140, 20);
    self.closeBtn.frame = CGRectMake(20, 10, 40, 20);
    self.infoBtn.frame = CGRectMake(kScreenWidth - 40, 10, 20, 20);
    
    self.rightMenuView.frame = CGRectMake(self.width - 60, 40, 40, self.height - 80);
    self.bottomMenuView.frame = CGRectMake(0, self.height-40, self.width, 40);
    //开始按钮
    self.playOrPauseBtn.frame = CGRectMake(self.bottomMenuView.left+5, 8, 36, 23);
    //当前时间
    self.currentLabel.frame = CGRectMake(self.playOrPauseBtn.right, 10, 45, 20);
    
    self.volumeView.frame = CGRectMake(0, 0, self.frame.size.height, self.frame.size.height * 9.0 / 16.0);
    if (isFull) {
        //如果全屏
        self.xjGestureButton.frame = self.window.bounds;

        self.topMenuView.hidden = NO;
        
        self.topTitle.hidden = NO;
        self.rightMenuView.hidden = NO;
    }else{
        self.rightMenuView.hidden = YES;
        self.topMenuView.hidden = YES;
        self.topTitle.hidden = YES;
        self.xjGestureButton.frame = CGRectMake(0, 0, xjPlayerFrame.size.width, xjPlayerFrame.size.height);
        
    }

    //全屏
    self.fullOrSmallBtn.frame = CGRectMake(self.bottomMenuView.width-35, 0, 35, self.bottomMenuView.height);

    self.loadProgressView.frame = CGRectMake(self.currentLabel.right + 10, 20, kScreenWidth - self.currentLabel.right - 105, 31);
    //总时间
    self.totalLabel.frame = CGRectMake(self.loadProgressView.right + 10, 10, 45, 20);

    self.playSlider.frame = CGRectMake(self.currentLabel.right, 5, self.loadProgressView.width+4, 31);
    
    
    
    self.loadingView.frame = CGRectMake(self.xjGestureButton.centerX, self.xjGestureButton.centerY-20, 20, 20);
}
#pragma mark - 关闭
- (void)closeClick{
    
    [self fullOrSmallAction];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.delegate backView];
        
    });
}
#pragma mark - 信息点击
- (void)infoClick{
    NSLog(@"点击");
}
- (void)dealloc {
    [self.xjPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
    [self.xjPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.link removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.xjPlayer removeTimeObserver:self.playbackTimeObserver];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

@end
