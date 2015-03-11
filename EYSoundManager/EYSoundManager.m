//
//  EYSoundManager.m
//  EYSoundManager
//
//  Created by ye on 15/3/11.
//  Copyright (c) 2015年 ye. All rights reserved.
//

#import "EYSoundManager.h"

@implementation EYSoundManager

+(EYSoundManager *)shareManager
{
    static EYSoundManager *eysoundManager = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        eysoundManager = [[self alloc] init];
    });
    return eysoundManager;
}

-(void)startStreamingAudioWithURL:(NSString *)url andBlock:(progressBlock)block
{
    if (_block) {
        [self stop];
    }
        
    _block = [block copy];
    NSURL *streamingURL = [NSURL URLWithString:url];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:streamingURL];
    _player = [[AVPlayer alloc]initWithPlayerItem:playerItem];
    [_player play];
    
    if (playerItem.status == AVPlayerItemStatusUnknown) {
        NSLog(@"AVPlayerItemStatusUnknown");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUNDMANAGER_STATUS_LOADING);
    }else if(playerItem.status == AVPlayerItemStatusFailed) {
        NSLog(@"AVPlayerItemStatusFailed");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUNDMANAGER_STATUS_ERROR);
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(failedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:playerItem];
    
    [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            void (^progressBlock)() = [block copy];
            Float64 durationTime = CMTimeGetSeconds(playerItem.asset.duration);
            Float64 currentTime = (time.value/time.timescale);
            progressBlock(currentTime/durationTime, currentTime, durationTime - currentTime, playerItem.error, EYSOUNDMANAGER_STATUS_PLAYING);
        }
    }];
}

-(void)didPlayToEndTime:(NSNotification *)sender
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:sender.object];
    _block(100.f, CMTimeGetSeconds([(AVPlayerItem *)(sender.object) duration]), 0.f, nil, EYSOUNDMANAGER_STATUS_FINISHED);
}

-(void)failedToPlayToEndTime:(NSNotification *)sender
{
    NSLog(@"failedToPlayToEndTime--%@", _player.currentItem.error.description);
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:sender.object];
    _block(0.f, 0.f, 0.f, _player.currentItem.error, EYSOUNDMANAGER_STATUS_LOADING);
}

//method
-(void)pause
{
    [_player pause];
    _block(0.f, 0.f, 0.f, _player.currentItem.error, EYSOUNDMANAGER_STATUS_LOADING);
}

-(void)stop
{
    int32_t timeScale = _player.currentItem.asset.duration.timescale;
    [_player seekToTime:CMTimeMake(0, timeScale)];
    [_player pause];
    _player = nil;
}

-(void)play
{
    [_player play];
}

-(void)replay
{
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];
}
@end
