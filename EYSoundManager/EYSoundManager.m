//
//  EYSoundManager.m
//  EYSoundManager
//
//  Created by ye on 15/3/11.
//  Copyright (c) 2015年 ye. All rights reserved.
//

#import "EYSoundManager.h"

@implementation EYSoundManager

+(EYSoundManager *)sharedManager
{
    static EYSoundManager *eysoundManager = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        eysoundManager = [[self alloc] init];
    });
    return eysoundManager;
}

-(void)startStreamingAudioWithURL:(NSString *)url usingBlock:(periodicBlock)block
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
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUNDMANAGER_STATUS_FAILED);
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(failedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackStalled:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:playerItem];
    
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    
    __block EYSoundManager *blockSelf = self;

    [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            void (^progressBlock)() = [block copy];
            Float64 durationTime = CMTimeGetSeconds(playerItem.asset.duration);
            Float64 currentTime = (time.value/time.timescale);
            progressBlock(currentTime/durationTime, currentTime, durationTime - currentTime, playerItem.error, blockSelf->_status);
        }
    }];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem*)object;
        if (playerItem.status==AVPlayerStatusReadyToPlay) {
            _status = EYSOUNDMANAGER_STATUS_PLAYING;
        }else if (playerItem.status==AVPlayerStatusFailed) {
            _status = EYSOUNDMANAGER_STATUS_FAILED;
        }else if (playerItem.status==AVPlayerStatusUnknown) {
            _status = EYSOUNDMANAGER_STATUS_LOADING;
        }
    }
}

-(void)didPlayToEndTime:(NSNotification *)sender
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:sender.object];
    _status = EYSOUNDMANAGER_STATUS_FINISHED;
}

-(void)failedToPlayToEndTime:(NSNotification *)sender
{
    NSLog(@"failedToPlayToEndTime--%@", _player.currentItem.error.description);
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:sender.object];
    _status = EYSOUNDMANAGER_STATUS_FAILED;
}

-(void)playbackStalled:(NSNotification *)sender
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:sender.object];
    NSLog(@"playbackStalled--%@", _player.currentItem.error.description);
}

//method
-(void)pause
{
    [_player pause];
    _status = EYSOUNDMANAGER_STATUS_PAUSE;
}

-(void)stop
{
    _status = EYSOUNDMANAGER_STATUS_STOPED;
    [_player pause];
    _player = nil;
}

-(void)play
{
    _status = EYSOUNDMANAGER_STATUS_PLAYING;
    [_player play];
}

-(void)replay
{
    [_player seekToTime:CMTimeMake(0, 1)];
    _status = EYSOUNDMANAGER_STATUS_PLAYING;
    [_player play];
}
@end
