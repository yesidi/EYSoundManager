//
//  EYSoundManager.h
//  EYSoundManager
//
//  Created by ye on 15/3/11.
//  Copyright (c) 2015年 ye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM (int, EYSOUNDMANAGER_STATUS) {
    EYSOUNDMANAGER_STATUS_PLAYING,
    EYSOUNDMANAGER_STATUS_PAUSE,
    EYSOUNDMANAGER_STATUS_STOPED,
    EYSOUNDMANAGER_STATUS_LOADING,
    EYSOUNDMANAGER_STATUS_FINISHED,
    EYSOUNDMANAGER_STATUS_ERROR,
};
typedef void (^progressBlock)(Float64 degree, Float64 elapsedTime, Float64 timeRemaining, NSError *error, EYSOUNDMANAGER_STATUS status);

@interface EYSoundManager : NSObject
+(EYSoundManager *)shareManager;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, copy) progressBlock block;
@property (nonatomic) EYSOUNDMANAGER_STATUS status;

-(void)startStreamingAudioWithURL:(NSString *)url andBlock:(progressBlock)block;
-(void)pause;
-(void)stop;
-(void)replay;
-(void)play;
@end
