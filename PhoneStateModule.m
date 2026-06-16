//
//  PhoneStateModule.m
//  NativeSpeed79
//
//  电话状态监听模块 (Objective-C 实现)
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <CallKit/CallKit.h>

@interface PhoneStateModule : RCTEventEmitter <CXCallObserverDelegate>

@property (nonatomic, strong) CXCallObserver *callObserver;
@property (nonatomic, assign) BOOL isListening;

@end

@implementation PhoneStateModule

static NSString *const EVENT_NAME = @"phoneStateChanged";

#pragma mark - RCTBridgeModule

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _isListening = NO;
        [self setupCallObserver];
    }
    return self;
}

- (void)dealloc {
    _isListening = NO;
    if (@available(iOS 10.0, *)) {
        [_callObserver setDelegate:nil queue:nil];
    }
    _callObserver = nil;
}

- (void)setupCallObserver {
    if (@available(iOS 10.0, *)) {
        self.callObserver = [[CXCallObserver alloc] init];
        [self.callObserver setDelegate:self queue:nil];
    }
}

#pragma mark - Public Methods (RCT_EXPORT)

/**
 * 开始监听电话状态变化
 */
RCT_EXPORT_METHOD(startListening:(RCTResponseSenderBlock)callback)
{
    @try {
        if (_isListening) {
            callback(@[@(YES)]);
            return;
        }

        // 如果 observer 被释放了，重新创建
        if (!_callObserver) {
            [self setupCallObserver];
        }

        _isListening = YES;
        callback(@[NSNull.null, @(YES)]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"START_ERROR"]);
    }
}

/**
 * 停止监听电话状态变化
 */
RCT_EXPORT_METHOD(stopListening:(RCTResponseSenderBlock)callback)
{
    @try {
        if (!_isListening) {
            callback(@[NSNull.null, @(YES)]);
            return;
        }

        _isListening = NO;
        callback(@[NSNull.null, @(YES)]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"STOP_ERROR"]);
    }
}

/**
 * 是否正在监听
 */
RCT_REMAP_METHOD(isListening,
                 isListeningWithCallback:(RCTResponseSenderBlock)callback)
{
    @try {
        callback(@[NSNull.null, @(_isListening)]);
    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"ERROR"]);
    }
}

/**
 * 获取当前状态（iOS CallKit 无法获取当前状态，返回基本信息）
 */
RCT_EXPORT_METHOD(getCurrentState:(RCTResponseSenderBlock)callback)
{
    @try {
        NSString *state = @"unknown";

        if (@available(iOS 10.0, *)) {
            NSArray<CXCall *> *calls = self.callObserver.calls;

            NSPredicate *activePredicate = [NSPredicate predicateWithFormat:@"hasEnded == NO"];
            NSArray<CXCall *> *activeCalls = [calls filteredArrayUsingPredicate:activePredicate];

            if (activeCalls.count == 0) {
                state = @"idle";
            } else {
                BOOL allOnHold = YES;
                for (CXCall *call in activeCalls) {
                    if (!call.isOnHold) {
                        allOnHold = NO;
                        break;
                    }
                }

                if (allOnHold) {
                    state = @"held";
                } else {
                    BOOL hasOutgoing = NO;
                    for (CXCall *call in activeCalls) {
                        if (call.isOutgoing) {
                            hasOutgoing = YES;
                            break;
                        }
                    }
                    state = hasOutgoing ? @"offhook" : @"ringing";
                }
            }
        }

        callback(@[NSNull.null, @{@"state": state}]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"STATE_ERROR"]);
    }
}

/**
 * 检查权限（iOS 不需要特殊权限）
 */
RCT_EXPORT_METHOD(checkPermission:(RCTResponseSenderBlock)callback)
{
    // iOS 使用 CallKit 不需要额外权限
    callback(@[@(YES)]);
}

#pragma mark - Test Methods (仅用于开发调试, Debug 模式可用)

/**
 * 模拟单个电话事件
 */
RCT_EXPORT_METHOD(simulateEvent:(NSString *)eventType
                  phoneNumber:(NSString *)phoneNumber
                  isIncoming:(BOOL)isIncoming
                  callback:(RCTResponseSenderBlock)callback)
{
#ifdef DEBUG
    @try {
        if (!_isListening) {
            callback(@[@"请先调用 startListening 开始监听"]);
            return;
        }

        [self sendEventWithType:eventType ?: @"incoming"
                     phoneNumber:phoneNumber ?: @"unknown"
                      isIncoming:isIncoming];

        callback(@[NSNull.null, @{@"success": @(YES), @"eventSent": eventType ?: @""}]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"SIMULATE_ERROR"]);
    }
#else
    callback(@"此方法仅在 Debug 模式下可用");
#endif
}

/**
 * 模拟完整来电流程：响铃 -> 接听 -> 挂断
 */
RCT_EXPORT_METHOD(simulateIncomingCall:(NSString *)phoneNumber
                  callback:(RCTResponseSenderBlock)callback)
{
#ifdef DEBUG
    @try {
        if (!_isListening) {
            callback(@[@"请先调用 startListening 开始监听"]);
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendEventWithType:@"incoming"
                         phoneNumber:phoneNumber ?: @"13800138000"
                          isIncoming:YES];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendEventWithType:@"answered"
                             phoneNumber:phoneNumber ?: @"13800138000"
                              isIncoming:YES];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self sendEventWithType:@"ended"
                                 phoneNumber:phoneNumber ?: @"13800138000"
                                  isIncoming:YES];
                });
            });
        });

        callback(@[NSNull.null, @{
            @"success": @(YES),
            @"message": @"开始模拟来电流程",
            @"steps": @[@"incoming(0.5s)", @"answered(3.5s)", @"ended(8.5s)"]
        }]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"SIMULATE_ERROR"]);
    }
#else
    callback(@"此方法仅在 Debug 模式下可用");
#endif
}

/**
 * 模拟未接来电流程：响铃 -> 未接
 */
RCT_EXPORT_METHOD(simulateMissedCall:(NSString *)phoneNumber
                  callback:(RCTResponseSenderBlock)callback)
{
#ifdef DEBUG
    @try {
        if (!_isListening) {
            callback(@[@"请先调用 startListening 开始监听"]);
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendEventWithType:@"incoming"
                         phoneNumber:phoneNumber ?: @"13800138000"
                          isIncoming:YES];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendEventWithType:@"missed"
                             phoneNumber:phoneNumber ?: @"13800138000"
                              isIncoming:YES];
            });
        });

        callback(@[NSNull.null, @{
            @"success": @(YES),
            @"message": @"开始模拟未接来电流程",
            @"steps": @[@"incoming(0.5s)", @"missed(4.5s)"]
        }]);

    } @catch (NSException *exception) {
        callback(@[exception.reason ?: @"SIMULATE_ERROR"]);
    }
#else
    callback(@"此方法仅在 Debug 模式下可用");
#endif
}

#pragma mark - Helper Methods

/**
 * 发送事件到 JavaScript
 */
- (void)sendEventWithType:(NSString *)eventType
               phoneNumber:(NSString *)phoneNumber
                isIncoming:(BOOL)isIncoming
{
    if (!_isListening || ![self.bridge isValid]) return;

    NSDictionary *params = @{
        @"eventType": eventType ?: @"unknown",
        @"phoneNumber": phoneNumber ?: @"unknown",
        @"isIncoming": @(isIncoming)
    };

    [self sendEventWithName:EVENT_NAME body:params];
}

#pragma mark - CXCallObserverDelegate

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call
{
    // iOS CallKit 提供的信息有限，无法获取具体号码
    // 只能判断通话状态变化

    if (!self.isListening) return;

    if (call.hasEnded) {
        // 通话结束
        [self sendEventWithType:@"ended"
                    phoneNumber:@"unknown"
                     isIncoming:!call.isOutgoing];

    } else if (call.isOnHold) {
        // 通话保持中（暂不处理）

    } else if (call.isOutgoing && !call.hasConnected) {
        // 正在拨出电话（尚未接通）
        [self sendEventWithType:@"outgoing"
                    phoneNumber:@"unknown"
                     isIncoming:NO];

    } else if (!call.isOutgoing && !call.hasConnected && !call.hasEnded) {
        // 来电响铃
        [self sendEventWithType:@"incoming"
                    phoneNumber:@"unknown"
                     isIncoming:YES];

    } else if (call.hasConnected && !call.hasEnded) {
        // 通话已连接
        [self sendEventWithType:@"answered"
                    phoneNumber:@"unknown"
                     isIncoming:!call.isOutgoing];
    }
}

#pragma mark - RCTEventEmitter Overrides

- (NSArray<NSString *> *)supportedEvents {
    return @[EVENT_NAME];
}

@end
