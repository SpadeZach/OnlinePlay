//
//  RightBtn.m
//  XJAVPlayer
//
//  Created by 赵博 on 2017/6/19.
//  Copyright © 2017年 Xander. All rights reserved.
//

#import "RightBtn.h"

@implementation RightBtn

- (instancetype)init{
    self = [super init];
    if (self) {
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    
    return self;
}
//- (void)layoutSubviews{
//    [super layoutSubviews];
//    //改坐标 -宽高 是60
//
//}
@end
