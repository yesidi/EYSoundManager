//
//  EYSoundManager.m
//  EYSoundManager
//
//  Created by ye on 15/3/11.
//  Copyright (c) 2015年 ye. All rights reserved.
//

#import "EYSoundManager.h"

@implementation EYSoundManager
@synthesize playObject;
@synthesize soundDelegate;

+(EYSoundManager *)sharedManager
{
    static EYSoundManager *eysoundManager = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        eysoundManager = [[self alloc] init];
    });
    return eysoundManager;
}

//处理监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification;
{
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗
    if ([[UIDevice currentDevice] proximityState] == YES)
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    else [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}

//播放本地资源
-(void)startPlayingLocalAudioWithPath:(NSString *)url tag:(NSString *)tag usingBlock:(periodicBlock)block
{
    if (_block) {
        [self stop];
    }
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
    //添加监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sensorStateChange:)
                                                 name:@"UIDeviceProximityStateDidChangeNotification"
                                               object:nil];
    _block = [block copy];
    _tag = tag;
    
    //初始化播放器的时候如下设置
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:[AVAsset assetWithURL:[NSURL fileURLWithPath:url]]];
    _player = [[AVPlayer alloc]initWithPlayerItem:playerItem];
    [_player play];
    if (playerItem.status == AVPlayerItemStatusUnknown) {
        NSLog(@"AVPlayerItemStatusUnknown");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_LOADING);
        [self.soundDelegate EYSoundPlayingStreamUrlWithDegree:0.f elapsedTime:0.f timeRemaining:0.f error:playerItem.error status:EYSOUND_AUDIO_STATUS_LOADING];

    }else if(playerItem.status == AVPlayerItemStatusFailed) {
        NSLog(@"AVPlayerItemStatusFailed");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_FAILED);
        [self.soundDelegate EYSoundPlayingStreamUrlWithDegree:0.f elapsedTime:0.f timeRemaining:0.f error:playerItem.error status:EYSOUND_AUDIO_STATUS_FAILED];

        _currentStreamingURL = nil;
        _tag = nil;
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
            Float64 durationTime = CMTimeGetSeconds(playerItem.duration);
            Float64 currentTime = (time.value/time.timescale);
            [blockSelf.soundDelegate EYSoundPlayingStreamUrlWithDegree:currentTime/durationTime elapsedTime:currentTime timeRemaining:durationTime - currentTime error:playerItem.error status:blockSelf->_status];
            progressBlock(currentTime/durationTime, currentTime, durationTime - currentTime, playerItem.error, blockSelf->_status);
        }
    }];

}

//播放网络资源
-(void)startStreamingAudioWithURL:(NSString *)url tag:(NSString *)tag usingBlock:(periodicBlock)block
{
    if (_block) {
        [self stop];
    }
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
    //添加监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sensorStateChange:)
                                                 name:@"UIDeviceProximityStateDidChangeNotification"
                                               object:nil];
    _block = [block copy];
    NSURL *streamingURL = [NSURL URLWithString:url];
    _currentStreamingURL = url;
    _tag = tag;
    
    //初始化播放器的时候如下设置
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:streamingURL];
    _player = [[AVPlayer alloc]initWithPlayerItem:playerItem];
    [_player play];
    if (playerItem.status == AVPlayerItemStatusUnknown) {
        NSLog(@"AVPlayerItemStatusUnknown");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_LOADING);
        [self.soundDelegate EYSoundPlayingStreamUrlWithDegree:0.f elapsedTime:0.f timeRemaining:0.f error:playerItem.error status:EYSOUND_AUDIO_STATUS_LOADING];

    }else if(playerItem.status == AVPlayerItemStatusFailed) {
        NSLog(@"AVPlayerItemStatusFailed");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_FAILED);
        [self.soundDelegate EYSoundPlayingStreamUrlWithDegree:0.f elapsedTime:0.f timeRemaining:0.f error:playerItem.error status:EYSOUND_AUDIO_STATUS_FAILED];
        _currentStreamingURL = nil;
        _tag = nil;
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

    [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, 1.0) queue:NULL usingBlock:^(CMTime time) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            void (^progressBlock)() = [block copy];
            Float64 durationTime = CMTimeGetSeconds(playerItem.duration);
            Float64 currentTime = (time.value/time.timescale);
            [blockSelf.soundDelegate EYSoundPlayingStreamUrlWithDegree:currentTime/durationTime elapsedTime:currentTime timeRemaining:durationTime - currentTime error:playerItem.error status:blockSelf->_status];
            progressBlock(currentTime/durationTime, currentTime, durationTime - currentTime, playerItem.error, blockSelf->_status);
        }
    }];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playerItem = (AVPlayerItem*)object;
        if (playerItem.status==AVPlayerStatusReadyToPlay) {
            _status = EYSOUND_AUDIO_STATUS_PLAYING;
        }else if (playerItem.status==AVPlayerStatusFailed) {
            _status = EYSOUND_AUDIO_STATUS_FAILED;
            _currentStreamingURL = nil;
            _tag = nil;
        }else if (playerItem.status==AVPlayerStatusUnknown) {
            _status = EYSOUND_AUDIO_STATUS_LOADING;
            _currentStreamingURL = nil;
            _tag = nil;
        }
    }
}

-(void)didPlayToEndTime:(NSNotification *)sender
{
    _status = EYSOUND_AUDIO_STATUS_FINISHED;
    _currentStreamingURL = nil;
    Float64 durationTime = CMTimeGetSeconds([(AVPlayerItem *)[sender object] duration]);
    _block(100.f, durationTime, 0.f, [(AVPlayerItem *)[sender object] error], _status);
    [self.soundDelegate EYSoundPlayingStreamUrlWithDegree:100.f elapsedTime:durationTime timeRemaining:0.f error:[(AVPlayerItem *)[sender object] error] status:_status];

    _tag = nil;

    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:sender.object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
}

-(void)failedToPlayToEndTime:(NSNotification *)sender
{
    NSLog(@"failedToPlayToEndTime--%@", _player.currentItem.error.description);
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:sender.object];
    _status = EYSOUND_AUDIO_STATUS_FAILED;
    _currentStreamingURL = nil;
    _tag = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)playbackStalled:(NSNotification *)sender
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:sender.object];
    NSLog(@"playbackStalled--%@", _player.currentItem.error.description);
}

//audio play method
-(void)pause
{
    [_player pause];
    _status = EYSOUND_AUDIO_STATUS_PAUSE;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)stop
{
    _status = EYSOUND_AUDIO_STATUS_STOPED;
    _currentStreamingURL = nil;
    _tag = nil;
    [_player pause];
    _player = nil;
    
    //移除监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)play
{
    _status = EYSOUND_AUDIO_STATUS_PLAYING;
    [_player play];
}

-(void)replay
{
    [_player seekToTime:CMTimeMake(0, 1)];
    _status = EYSOUND_AUDIO_STATUS_PLAYING;
    [_player play];
}

//record method
-(void)startRecordingWithFileName:(NSString *)name andExtension:(NSString *)extension forDuration:(NSTimeInterval)second prepare:(prepareBlock)prepareBlock usingBlock:(recordBlock)block micNotOpened:(micAuthorityBlock)micAuthorityBlock
{
    if (_recorder.isRecording)
        [self cancelRecording];
    
    if (![self isAllowRecord]) {
        micAuthorityBlock();
        return;
    }
    prepareBlock();
    
    _eyRecordBlock = [block copy];
    self.displaylink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeters)];

    NSDictionary *settings=[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                            AVFormatIDKey,
                            [NSNumber numberWithFloat:44100.f],
                            AVSampleRateKey,
                            [NSNumber numberWithInt:1],
                            AVNumberOfChannelsKey, nil];
    
    NSError *recorderError = nil;
    NSError *sessionError = nil;
    _recorder = [[AVAudioRecorder alloc]initWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.%@", NSTemporaryDirectory(), name, extension]] settings:settings error:&recorderError];
    _recorder.delegate = self;

    if (recorderError) {
        NSLog(@"recorderError:%@", recorderError.description);
        return;
    }
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    if (sessionError) {
        NSLog(@"sessionError:%@", sessionError.description);
        return;
    }
    [_recorder setMeteringEnabled:YES];
    [self.displaylink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    if (second == 0 && !second) {
        [_recorder record];
    } else {
        [_recorder recordForDuration:second];
    }
}

- (void)updateMeters
{
    [_recorder updateMeters];
    _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_RECORDING);
}

-(void)pauseRecording {
    if ([_recorder isRecording]) {
        [_recorder pause];
        [self.displaylink setPaused:YES];
        _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_PAUSE);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)resumeRecording {
    if (![_recorder isRecording]) {
        [_recorder record];
        [self.displaylink setPaused:NO];
        _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_RECORDING);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)stopAndSaveRecording {
    _recorder.delegate = nil;
    [self.displaylink setPaused:YES];
    [_recorder stop];
    _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_STOP);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)cancelRecording {
    _recorder.delegate = nil;
    [self.displaylink setPaused:YES];
    [_recorder stop];
    [_recorder deleteRecording];
    _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_STOP);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if (flag)
    {
        [self.displaylink setPaused:YES];
        _eyRecordBlock(recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_FINISHED);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应

}

- (BOOL)isAllowRecord
{
    __block BOOL bCanRecord = YES;
    if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 7.0) {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                if (granted) {
                    bCanRecord = YES;
                } else {
                    bCanRecord = NO;
                }
            }];
        }
    }
    return bCanRecord;
}
@end
