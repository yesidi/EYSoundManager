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

-(void)startStreamingAudioWithURL:(NSString *)url tag:(NSString *)tag usingBlock:(periodicBlock)block
{
    if (_block) {
        [self stop];
    }
    
    _block = [block copy];
    NSURL *streamingURL = [NSURL URLWithString:url];
    _currentStreamingURL = url;
    _tag = tag;
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:streamingURL];
    _player = [[AVPlayer alloc]initWithPlayerItem:playerItem];
    [_player play];
    if (playerItem.status == AVPlayerItemStatusUnknown) {
        NSLog(@"AVPlayerItemStatusUnknown");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_LOADING);
    }else if(playerItem.status == AVPlayerItemStatusFailed) {
        NSLog(@"AVPlayerItemStatusFailed");
        _block(0.f, 0.f, 0.f, playerItem.error, EYSOUND_AUDIO_STATUS_FAILED);
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
    _tag = nil;
    Float64 durationTime = CMTimeGetSeconds([(AVPlayerItem *)[sender object] duration]);
    _block(100.f, durationTime, 0.f, [(AVPlayerItem *)[sender object] error], _status);
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:sender.object];
}

-(void)failedToPlayToEndTime:(NSNotification *)sender
{
    NSLog(@"failedToPlayToEndTime--%@", _player.currentItem.error.description);
    [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:sender.object];
    _status = EYSOUND_AUDIO_STATUS_FAILED;
    _currentStreamingURL = nil;
    _tag = nil;
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
}

-(void)stop
{
    _status = EYSOUND_AUDIO_STATUS_STOPED;
    _currentStreamingURL = nil;
    _tag = nil;
    [_player pause];
    _player = nil;
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
-(void)startRecordingWithFileName:(NSString *)name andExtension:(NSString *)extension forDuration:(NSTimeInterval)second usingBlock:(recordBlock)block
{
    if (_recorder.isRecording)
        [self cancelRecording];
    
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

    _recorder = [[AVAudioRecorder alloc]initWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@.%@", NSTemporaryDirectory(), name, extension]] settings:settings error:&recorderError];
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
}

-(void)resumeRecording {
    if (![_recorder isRecording]) {
        [_recorder record];
        [self.displaylink setPaused:NO];
        _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_RECORDING);
    }
}

-(void)stopAndSaveRecording {
    _recorder.delegate = nil;
    [self.displaylink setPaused:YES];
    [_recorder stop];
    _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_STOP);
}

-(void)cancelRecording {
    _recorder.delegate = nil;
    [self.displaylink setPaused:YES];
    [_recorder stop];
    [_recorder deleteRecording];
    _eyRecordBlock(_recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_STOP);
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if (flag)
    {
        [self.displaylink setPaused:YES];
        _eyRecordBlock(recorder.currentTime, [_recorder averagePowerForChannel:0], EYSOUND_RECORD_STATUS_FINISHED);
    }
}

@end
