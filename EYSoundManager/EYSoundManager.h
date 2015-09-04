//
//  EYSoundManager.h
//  EYSoundManager
//
//  Created by ye on 15/3/11.
//  Copyright (c) 2015年 ye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM (int, EYSOUND_AUDIO_STATUS) {
    EYSOUND_AUDIO_STATUS_PLAYING,
    EYSOUND_AUDIO_STATUS_PAUSE,
    EYSOUND_AUDIO_STATUS_FINISHED,
    EYSOUND_AUDIO_STATUS_STOPED,
    EYSOUND_AUDIO_STATUS_LOADING,
    EYSOUND_AUDIO_STATUS_FAILED,
};

typedef NS_ENUM (int, EYSOUND_RECORD_STATUS) {
    EYSOUND_RECORD_STATUS_RECORDING,
    EYSOUND_RECORD_STATUS_PAUSE,
    EYSOUND_RECORD_STATUS_STOP,
    EYSOUND_RECORD_STATUS_FINISHED,
};

@protocol EYSoundDelegate <NSObject>
@optional
-(void)EYSoundPlayingStreamUrlWithDegree:(Float64)degree elapsedTime:(Float64)elapsedTime timeRemaining:(Float64)timeRemaining error:(NSError *)error status:(EYSOUND_AUDIO_STATUS)status;
@end

typedef void (^periodicBlock)(Float64 degree, Float64 elapsedTime, Float64 timeRemaining, NSError *error, EYSOUND_AUDIO_STATUS status);
typedef void (^recordBlock)(NSTimeInterval currentTime, Float64 averagePower, EYSOUND_RECORD_STATUS status);
typedef void (^micAuthorityBlock)();
typedef void (^prepareBlock)();

@interface EYSoundManager : NSObject<AVAudioRecorderDelegate>
@property (nonatomic, strong) id <EYSoundDelegate> soundDelegate;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, copy) periodicBlock block;
@property (nonatomic, copy) recordBlock eyRecordBlock;
@property (nonatomic) EYSOUND_AUDIO_STATUS status;
@property (nonatomic) EYSOUND_RECORD_STATUS recordStatus;
@property (nonatomic, strong) NSString *currentStreamingURL;
@property (nonatomic, strong) NSString *tag;
@property (nonatomic, strong) CADisplayLink *displaylink;
@property (nonatomic, strong) id playObject;

+(EYSoundManager *)sharedManager;
-(void)startStreamingAudioWithURL:(NSString *)url tag:(NSString *)tag usingBlock:(periodicBlock)block;
-(void)startPlayingLocalAudioWithPath:(NSString *)url tag:(NSString *)tag usingBlock:(periodicBlock)block;

-(void)pause;
-(void)stop;
-(void)replay;
-(void)play;

//record
-(void)startRecordingWithFileName:(NSString *)name andExtension:(NSString *)extension forDuration:(NSTimeInterval)second prepare:(prepareBlock)prepareBlock usingBlock:(recordBlock)block micNotOpened:(micAuthorityBlock)micAuthorityBlock;
-(void)pauseRecording;
-(void)resumeRecording;
-(void)stopAndSaveRecording;
-(void)cancelRecording;

@end
