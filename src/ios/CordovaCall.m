#import <Cordova/CDV.h>
#import <CallKit/CallKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CordovaCall : CDVPlugin <CXProviderDelegate>
@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXCallController *callController;

@property (nonatomic) BOOL hasVideo;
@property (nonatomic, strong) NSString *applicationName;
@property (nonatomic, strong) NSString *ringtoneName;
@property (nonatomic, strong) NSString *iconName;
@property (nonatomic) BOOL shouldIncludeInRecents;
@property (nonatomic, strong) NSMutableDictionary *callbackIds;
@property (nonatomic, strong) NSMutableDictionary *receivedUUIDsToRemoteHandles;
@property (nonatomic, strong) NSDictionary *pendingCallFromRecents;
@property (nonatomic) BOOL monitorAudioRouteChange;
@property (nonatomic) BOOL enableDTMF;
@property (nonatomic) BOOL keepAlive;
@property (nonatomic) BOOL backgroundExecution;


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

@implementation CordovaCall

- (void)pluginInitialize
{
	CXProviderConfiguration *providerConfiguration;
	self.applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	providerConfiguration = [[CXProviderConfiguration alloc] initWithLocalizedName:self.applicationName];
	providerConfiguration.maximumCallsPerCallGroup = 1;
	NSMutableSet *handleTypes = [[NSMutableSet alloc] init];
	[handleTypes addObject:@(CXHandleTypePhoneNumber)];
	providerConfiguration.supportedHandleTypes = handleTypes;
	providerConfiguration.supportsVideo = YES;
	if (@available(iOS 11.0, *)) {
		providerConfiguration.includesCallsInRecents = NO;
	}
	self.provider = [[CXProvider alloc] initWithConfiguration:providerConfiguration];
	[self.provider setDelegate:self queue:nil];
	self.callController = [[CXCallController alloc] init];
	//initialize callback dictionary
	self.callbackIds = [[NSMutableDictionary alloc] initWithCapacity:13];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"answer"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"reject"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"hangup"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"sendCall"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"receiveCall"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"mute"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"unmute"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"speakerOn"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"speakerOff"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"DTMF"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"hold"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"resume"];
	[self.callbackIds setObject:[NSMutableArray array] forKey:@"keepAlive"];

	[self.callbackIds setObject:[NSMutableArray array] forKey:@"applicationStateIsBackground"];
	
	
	self.receivedUUIDsToRemoteHandles = [NSMutableDictionary dictionary];
	
	//allows user to make call from recents
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCallFromRecents:) name:@"RecentsCallNotification" object:nil];
	//detect Audio Route Changes to make speakerOn and speakerOff event handlers
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundStateChange:) name:@"com.nfon.applicationstate.isBackground" object:nil];
}

- (void) handleBackgroundStateChange:(NSNotification*) notification {
	BOOL backgroundState = [notification.userInfo[@"isBackground"] boolValue];
	
	if (self.backgroundExecution && backgroundState) {
		[self keepAliveInternal:YES];
	} else {
		[self keepAliveInternal:NO];
	}
	
	for (id callbackId in self.callbackIds[@"applicationStateIsBackground"]) {
		CDVPluginResult* pluginResult = nil;
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:backgroundState];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
}

- (void) keepAlive:(CDVInvokedUrlCommand*)command {
	[self keepAliveInternal:[command.arguments[0] boolValue]];
}

- (void) keepAliveInternal:(BOOL)enable {
	BOOL oldValueKA = self.keepAlive;
	self.keepAlive = enable;
	
	if (enable && !oldValueKA) {
		[self _keepAlive:1];
	}
}
dispatch_queue_t backgroundQueue;

- (void) _keepAlive:(NSTimeInterval)interval {
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		backgroundQueue = dispatch_queue_create("com.nfon.myqueue", 0);
	});
	dispatch_async(backgroundQueue, ^{
		while (self.keepAlive) {
			dispatch_async(dispatch_get_main_queue(), ^{
				CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{}];
				[pluginResult setKeepCallbackAsBool:YES];
				for (id callbackId in self.callbackIds[@"keepAlive"]) {
					[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
				}
			});
			
			[NSThread sleepForTimeInterval:interval];
		}
	});
}

- (void) enableLimitedBackgroundExecution:(CDVInvokedUrlCommand *)command {
	BOOL backgroundExecution = [[command.arguments objectAtIndex:0] boolValue];
	BOOL oldValueBE = self.backgroundExecution;
	self.backgroundExecution = backgroundExecution;

	if (backgroundExecution && !oldValueBE) {
		[self _enableLimitedBackgroundExecution:10 runningTask:UIBackgroundTaskInvalid];
	}
}

- (void) _enableLimitedBackgroundExecution:(NSInteger)taskLengthInSeconds runningTask:(UIBackgroundTaskIdentifier)runningTask {
	__block UIBackgroundTaskIdentifier rTask = runningTask;
	
	if (rTask == UIBackgroundTaskInvalid) {
		rTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
			[[UIApplication sharedApplication] endBackgroundTask:rTask];
			rTask = UIBackgroundTaskInvalid;
		}];
	}
	
	__block UIBackgroundTaskIdentifier ntask = UIBackgroundTaskInvalid;
	
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MIN(taskLengthInSeconds - 1, 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if(self.backgroundExecution) {
			ntask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
				[[UIApplication sharedApplication] endBackgroundTask:ntask];
				ntask = UIBackgroundTaskInvalid;
			}];
		}
	});
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(taskLengthInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[[UIApplication sharedApplication] endBackgroundTask:rTask];
		rTask = UIBackgroundTaskInvalid;
		
		if (self.backgroundExecution) {
			
			[self _enableLimitedBackgroundExecution:taskLengthInSeconds runningTask:ntask];
		}
	});
}

- (void) getApplicationState:(CDVInvokedUrlCommand *)command
{
	BOOL isBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateInactive || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
	
	[self.commandDelegate sendPluginResult: [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:isBackground] callbackId:command.callbackId];
}

- (void)updateProviderConfig {
	CXProviderConfiguration *providerConfiguration;
	providerConfiguration = [[CXProviderConfiguration alloc] initWithLocalizedName: self.applicationName];
	providerConfiguration.maximumCallsPerCallGroup = 1;
	if(self.ringtoneName != nil) {
		providerConfiguration.ringtoneSound = self.ringtoneName;
	}
	if(self.iconName != nil) {
		UIImage *iconImage = [UIImage imageNamed:self.iconName];
		NSData *iconData = UIImagePNGRepresentation(iconImage);
		providerConfiguration.iconTemplateImageData = iconData;
	}
	NSMutableSet *handleTypes = [[NSMutableSet alloc] init];
	[handleTypes addObject:@(CXHandleTypePhoneNumber)];
	providerConfiguration.supportedHandleTypes = handleTypes;
	providerConfiguration.supportsVideo = self.hasVideo;
	if (@available(iOS 11.0, *)) {
		providerConfiguration.includesCallsInRecents = self.shouldIncludeInRecents;
	}
	
	self.provider.configuration = providerConfiguration;
}

- (void)setAppName:(CDVInvokedUrlCommand *)command
{
	CDVPluginResult* pluginResult = nil;
	NSString* proposedAppName = [command.arguments objectAtIndex:0];
	
	if (proposedAppName != nil && [proposedAppName length] > 0) {
		self.applicationName = proposedAppName;
		[self updateProviderConfig];
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"App Name Changed Successfully"];
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"App Name Can't Be Empty"];
	}
	
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setIcon:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	NSString* proposedIconName = [command.arguments objectAtIndex:0];
	
	if (proposedIconName == nil || [proposedIconName length] == 0) {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Icon Name Can't Be Empty"];
	} else if([UIImage imageNamed:proposedIconName] == nil) {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"This icon does not exist. Make sure to add it to your project the right way."];
	} else {
		self.iconName = proposedIconName;
		[self updateProviderConfig];
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Icon Changed Successfully"];
	}
	
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setRingtone:(CDVInvokedUrlCommand *)command
{
	CDVPluginResult* pluginResult = nil;
	NSString* proposedRingtoneName = [command.arguments objectAtIndex:0];
	
	if (proposedRingtoneName == nil || [proposedRingtoneName length] == 0) {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Ringtone Name Can't Be Empty"];
	} else {
		self.ringtoneName = [NSString stringWithFormat: @"%@.caf", proposedRingtoneName];
		[self updateProviderConfig];
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Ringtone Changed Successfully"];
	}
	
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setIncludeInRecents:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	self.shouldIncludeInRecents = [[command.arguments objectAtIndex:0] boolValue];
	[self updateProviderConfig];
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"includeInRecents Changed Successfully"];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setDTMFState:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	self.enableDTMF = [[command.arguments objectAtIndex:0] boolValue];
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"enableDTMF Changed Successfully"];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setVideo:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	self.hasVideo = [[command.arguments objectAtIndex:0] boolValue];
	[self updateProviderConfig];
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"hasVideo Changed Successfully"];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)receiveCall:(CDVInvokedUrlCommand*)command
{
	BOOL hasId = ![[command.arguments objectAtIndex:1] isEqual:[NSNull null]];
	NSString* callName = [command.arguments objectAtIndex:0];
	NSString* callId = hasId?[command.arguments objectAtIndex:1]:callName;
	BOOL supportsHolding = [command.arguments count] >= 3 ? [[command.arguments objectAtIndex:2] boolValue] : NO;
	
	NSUUID *callUUID = [[NSUUID alloc] init];
	
	if (hasId) {
		[[NSUserDefaults standardUserDefaults] setObject:callName forKey:[command.arguments objectAtIndex:1]];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	if (callName != nil && [callName length] > 0) {
		CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:callId];
		self.receivedUUIDsToRemoteHandles[callUUID] = handle;
		
		CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
		callUpdate.hasVideo = self.hasVideo;
		callUpdate.localizedCallerName = callName;
		callUpdate.supportsGrouping = NO;
		callUpdate.supportsUngrouping = NO;
		callUpdate.supportsHolding = supportsHolding;
		callUpdate.supportsDTMF = self.enableDTMF;
		
		[self.provider reportNewIncomingCallWithUUID:callUUID update:callUpdate completion:^(NSError * _Nullable error) {
			if(error == nil) {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[callUUID UUIDString]] callbackId:command.callbackId];
			} else {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]] callbackId:command.callbackId];
			}
		}];
		for (id callbackId in self.callbackIds[@"receiveCall"]) {
			CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[callUUID UUIDString]];
			[pluginResult setKeepCallbackAsBool:YES];
			[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
		}
	} else {
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Caller id can't be empty"] callbackId:command.callbackId];
	}
}

- (void)sendCall:(CDVInvokedUrlCommand*)command
{
	BOOL hasId = ![[command.arguments objectAtIndex:1] isEqual:[NSNull null]];
	NSString* callName = [command.arguments objectAtIndex:0];
	NSString* callId = hasId?[command.arguments objectAtIndex:1]:callName;
	NSUUID *callUUID = [[NSUUID alloc] init];
	
	if (hasId) {
		[[NSUserDefaults standardUserDefaults] setObject:callName forKey:[command.arguments objectAtIndex:1]];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	if (callName != nil && [callName length] > 0) {
		CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:callId];
		CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:handle];
		startCallAction.contactIdentifier = callName;
		startCallAction.video = self.hasVideo;
		CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
		[self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
			if (error == nil) {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[callUUID UUIDString]] callbackId:command.callbackId];
			} else {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]] callbackId:command.callbackId];
			}
		}];
	} else {
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The caller id can't be empty"] callbackId:command.callbackId];
	}
}

- (void)connectCall:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	NSUUID* callUUID = nil;
	if (
		[command.arguments objectAtIndex:0] != nil && [command.arguments objectAtIndex:0] != (id)[NSNull null] &&
		(callUUID = [[NSUUID alloc] initWithUUIDString:[command.arguments objectAtIndex:0]]) != nil){
		[self.provider reportOutgoingCallWithUUID:callUUID connectedAtDate:nil];
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Call connected successfully"];
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No UUID found in command."];
		
	}
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)endCall:(CDVInvokedUrlCommand*)command
{
	NSUUID* callUUID = nil;
	if (
		[command.arguments objectAtIndex:0] != nil && [command.arguments objectAtIndex:0] != (id)[NSNull null] &&
		(callUUID = [[NSUUID alloc] initWithUUIDString:[command.arguments objectAtIndex:0]]) != nil){
		
		if (command.arguments.count > 1 &&
			[command.arguments objectAtIndex:1] != nil &&
			[command.arguments objectAtIndex:1] != (id)[NSNull null] &&
			[command.arguments[1] boolValue]) {
			[self setRecentsIntegration:NO];
			
			[NSTimer scheduledTimerWithTimeInterval:.03 target:self selector:@selector(activateRecentsIntegration) userInfo:nil repeats:NO];
		}
		
		CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:callUUID];
		CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
		[self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
			if (error == nil) {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Call ended successfully"] callbackId:command.callbackId];
			} else {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]] callbackId:command.callbackId];
			}
		}];
	} else if ([self.callController.callObserver.calls count] > 0) {
		for (CXCall* call in self.callController.callObserver.calls) {
			
			CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:call.UUID];
			CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
			[self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
				if (error != nil) {
					NSLog(@"%@",[error localizedDescription]);
				}
			}];
		}
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Call ended successfully"] callbackId:command.callbackId];
	} else {
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"No calls found."] callbackId:command.callbackId];
	}
}

- (void) activateRecentsIntegration {
	[self setRecentsIntegration:YES];
}

- (void) setRecentsIntegration:(BOOL) active {
	self.shouldIncludeInRecents = active;
	[self updateProviderConfig];
}

- (void)registerEvent:(CDVInvokedUrlCommand*)command;
{
	NSString* eventName = [command.arguments objectAtIndex:0];
	if(self.callbackIds[eventName] != nil) {
		[self.callbackIds[eventName] addObject:command.callbackId];
	}
	if(self.pendingCallFromRecents && [eventName isEqual:@"sendCall"]) {
		NSDictionary *callData = self.pendingCallFromRecents;
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:callData];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	}
}

- (void) receiveCallFromRecents:(NSNotification *) notification
{
	NSString* callID = notification.object[@"callId"];
	NSString* callName = notification.object[@"callName"];
	
	NSDictionary *callData = @{ @"callName": callName, @"callId": callID, @"message": @"sendCall event called successfully" };
	for (id callbackId in self.callbackIds[@"sendCall"]) {
		CDVPluginResult* pluginResult = nil;
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:callData];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	if([self.callbackIds[@"sendCall"] count] == 0) {
		self.pendingCallFromRecents = callData;
	}
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action
{
	[self setupAudioSession];
	CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
	callUpdate.remoteHandle = action.handle;
	callUpdate.hasVideo = action.video;
	callUpdate.localizedCallerName = action.contactIdentifier;
	callUpdate.supportsGrouping = NO;
	callUpdate.supportsUngrouping = NO;
	callUpdate.supportsHolding = YES;
	callUpdate.supportsDTMF = self.enableDTMF;
	//
	[self.provider reportCallWithUUID:action.callUUID updated:callUpdate];
	NSDictionary *callData = @{ @"callName":action.contactIdentifier, @"callId": action.handle.value, @"isVideo": action.video?@YES:@NO, @"message": @"sendCall event called successfully", @"callUUID": [action.callUUID UUIDString] };
	for (id callbackId in self.callbackIds[@"sendCall"]) {
		CDVPluginResult* pluginResult = nil;
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:callData];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	if([self.callbackIds[@"sendCall"] count] == 0) {
		self.pendingCallFromRecents = callData;
	}
	[action fulfill];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
	NSLog(@"activated audio");
	self.monitorAudioRouteChange = YES;
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
	NSLog(@"deactivated audio");
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
	NSArray* callbacks = action.onHold ? self.callbackIds[@"hold"] : self.callbackIds[@"resume"];
	
	for (id callbackId in callbacks) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[action.callUUID UUIDString]];;
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	
	[action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
	[self setupAudioSession];
	for (id callbackId in self.callbackIds[@"answer"]) {
		CDVPluginResult* pluginResult = nil;
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[action.callUUID UUIDString]];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	[action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
	NSArray<CXCall *> *calls = self.callController.callObserver.calls;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"UUID == %@", action.callUUID];
	NSArray<CXCall *> *filteredArray = [calls filteredArrayUsingPredicate:predicate];
	
	if (self.receivedUUIDsToRemoteHandles[action.callUUID]) {
		CXCallUpdate* update = [[CXCallUpdate alloc] init];
		update.remoteHandle = self.receivedUUIDsToRemoteHandles[action.callUUID];
		[self.provider reportCallWithUUID:action.callUUID updated:update];
		[self.receivedUUIDsToRemoteHandles removeObjectForKey:action.UUID];
	}
	
	if([filteredArray count] >= 1) {
		if(filteredArray.firstObject.hasConnected) {
			for (id callbackId in self.callbackIds[@"hangup"]) {
				CDVPluginResult* pluginResult = nil;
				pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[action.callUUID UUIDString]];
				[pluginResult setKeepCallbackAsBool:YES];
				[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
			}
		} else {
			for (id callbackId in self.callbackIds[@"reject"]) {
				CDVPluginResult* pluginResult = nil;
				pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[action.callUUID UUIDString]];
				[pluginResult setKeepCallbackAsBool:YES];
				[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
			}
		}
	}
	
	
	self.monitorAudioRouteChange = NO;
	[action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action
{
	BOOL isMuted = action.muted;
	
	for (id callbackId in self.callbackIds[isMuted?@"mute":@"unmute"]) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[action.callUUID UUIDString]];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	[action fulfill];
}

- (void)setupAudioSession
{
	@try {
		AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
		[sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
		[sessionInstance setMode:AVAudioSessionModeVoiceChat error:nil];
		NSTimeInterval bufferDuration = .005;
		[sessionInstance setPreferredIOBufferDuration:bufferDuration error:nil];
		[sessionInstance setPreferredSampleRate:44100 error:nil];
		
		NSLog(@"Configuring Audio");
	}
	@catch (NSException *exception) {
		NSLog(@"Unknown error returned from setupAudioSession");
	}
	return;
}

- (void)handleAudioRouteChange:(NSNotification *) notification
{
	if(self.monitorAudioRouteChange) {
		NSNumber* reasonValue = notification.userInfo[@"AVAudioSessionRouteChangeReasonKey"];
		AVAudioSessionRouteDescription* previousRouteKey = notification.userInfo[@"AVAudioSessionRouteChangePreviousRouteKey"];
		NSArray* outputs = [previousRouteKey outputs];
		if([outputs count] > 0) {
			AVAudioSessionPortDescription *output = outputs[0];
			if(![output.portType isEqual: @"Speaker"] && [reasonValue isEqual:@4]) {
				for (id callbackId in self.callbackIds[@"speakerOn"]) {
					CDVPluginResult* pluginResult = nil;
					pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"speakerOn event called successfully"];
					[pluginResult setKeepCallbackAsBool:YES];
					[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
				}
			} else if([output.portType isEqual: @"Speaker"] && [reasonValue isEqual:@3]) {
				for (id callbackId in self.callbackIds[@"speakerOff"]) {
					CDVPluginResult* pluginResult = nil;
					pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"speakerOff event called successfully"];
					[pluginResult setKeepCallbackAsBool:YES];
					[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
				}
			}
		}
	}
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action
{
	NSLog(@"DTMF Event");
	NSString *digits = action.digits;
	for (id callbackId in self.callbackIds[@"DTMF"]) {
		CDVPluginResult* pluginResult = nil;
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:digits];
		[pluginResult setKeepCallbackAsBool:YES];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
	}
	
	[action fulfill];
}


- (void)setMuteCall:(CDVInvokedUrlCommand*)command
{
	NSUUID* callUUID = nil;
	BOOL mute;
	if (
		command.arguments.count > 1 &&
		[command.arguments objectAtIndex:0] != nil && [command.arguments objectAtIndex:0] != (id)[NSNull null] &&
		[command.arguments objectAtIndex:1] != nil && [command.arguments objectAtIndex:1] != (id)[NSNull null] &&
		(callUUID = [[NSUUID alloc] initWithUUIDString:[command.arguments objectAtIndex:0]]) != nil){
		mute = [[command.arguments objectAtIndex:1] boolValue];
		CXTransaction *transaction = [[CXTransaction alloc] initWithAction:[[CXSetMutedCallAction alloc] initWithCallUUID:callUUID muted:mute]];
		[self.callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
			if (error == nil) {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Mute status set successfully"] callbackId:command.callbackId];
			} else {
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"An error occurred setting mute"] callbackId:command.callbackId];
			}
		}];
	} else {
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Mute call: Invalid number of arguments."] callbackId:command.callbackId];
	}
}

- (void)mute:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	if(sessionInstance.isInputGainSettable) {
		BOOL success = [sessionInstance setInputGain:0.0 error:nil];
		if(success) {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Muted Successfully"];
		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"An error occurred"];
		}
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not muted because this device does not allow changing inputGain"];
	}
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unmute:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	if(sessionInstance.isInputGainSettable) {
		BOOL success = [sessionInstance setInputGain:1.0 error:nil];
		if(success) {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Muted Successfully"];
		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"An error occurred"];
		}
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not unmuted because this device does not allow changing inputGain"];
	}
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)speakerOn:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	BOOL success = [sessionInstance overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
	if(success) {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Speakerphone is on"];
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"An error occurred"];
	}
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)speakerOff:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
	BOOL success = [sessionInstance overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
	if(success) {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Speakerphone is off"];
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"An error occurred"];
	}
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)callNumber:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult = nil;
	NSString* phoneNumber = [command.arguments objectAtIndex:0];
	NSString* telNumber = [@"tel://" stringByAppendingString:phoneNumber];
	if (@available(iOS 10.0, *)) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:telNumber]
										   options:nil
								 completionHandler:^(BOOL success) {
									 if(success) {
										 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Call Successful"];
										 [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
									 } else {
										 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Call Failed"];
										 [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
									 }
								 }];
	} else {
		BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telNumber]];
		if(success) {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Call Successful"];
		} else {
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Call Failed"];
		}
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	}
}

@end
