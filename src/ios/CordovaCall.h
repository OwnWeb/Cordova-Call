#import <Cordova/CDV.h>
#import <CallKit/CallKit.h>
#import <AVFoundation/AVFoundation.h>
#import <PushKit/PushKit.h>


@interface CordovaCall : CDVPlugin <CXProviderDelegate, PKPushRegistryDelegate>

+ (id)sharedInstance;

@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXCallController *callController;

@property (nonatomic) BOOL hasVideo;
@property (nonatomic, strong) NSString *applicationName;
@property (nonatomic, strong) NSString *ringtoneName;
@property (nonatomic, strong) NSString *iconName;
@property (nonatomic) BOOL shouldIncludeInRecents;
@property (nonatomic, strong) NSMutableDictionary *callbackIds;
@property (nonatomic, strong) NSMutableDictionary *receivedUUIDsToRemoteHandles;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSUUID*> *callIDtoUUID;

@property (nonatomic, strong) NSDictionary *pendingCallFromRecents;
@property (nonatomic) BOOL monitorAudioRouteChange;
@property (nonatomic) BOOL enableDTMF;
@property (nonatomic) BOOL keepAlive;
@property (nonatomic) BOOL backgroundExecution;
@property (nonatomic, copy) NSString *callbackId;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

- (void)voipRegistration:(CDVInvokedUrlCommand*)command;

- (void)updateProviderConfig;
- (void)keepAlive:(CDVInvokedUrlCommand*)command;
- (void)enableLimitedBackgroundExecution:(CDVInvokedUrlCommand *)command;
- (void)setAppName:(CDVInvokedUrlCommand*)command;
- (void)setIcon:(CDVInvokedUrlCommand*)command;
- (void)setRingtone:(CDVInvokedUrlCommand*)command;
- (void)setIncludeInRecents:(CDVInvokedUrlCommand*)command;
- (void)receiveCall:(CDVInvokedUrlCommand*)command;
- (void)sendCall:(CDVInvokedUrlCommand*)command;
- (void)connectCall:(CDVInvokedUrlCommand*)command;
- (void)endCall:(CDVInvokedUrlCommand*)command;
- (void)registerEvent:(CDVInvokedUrlCommand*)command;
- (void)mute:(CDVInvokedUrlCommand*)command;
- (void)unmute:(CDVInvokedUrlCommand*)command;
- (void)speakerOn:(CDVInvokedUrlCommand*)command;
- (void)speakerOff:(CDVInvokedUrlCommand*)command;
- (void)callNumber:(CDVInvokedUrlCommand*)command;
- (void)receiveCallFromRecents:(NSNotification *) notification;
- (void)setupAudioSession;
- (void)setDTMFState:(CDVInvokedUrlCommand*)command;

@end
