#import "CallDetector.h"

@implementation CallDetector {
  BOOL hasListeners;
}

RCT_EXPORT_MODULE();

// 当 JS 侧开始监听时触发
- (void)startObserving {
  hasListeners = YES;
  if (!self.callObserver) {
    self.callObserver = [[CXCallObserver alloc] init];
  }
  [self.callObserver setDelegate:self queue:nil];
}

// 当 JS 侧移除监听时触发
- (void)stopObserving {
  hasListeners = NO;
  [self.callObserver setDelegate:nil queue:nil];
}

// 声明支持的事件名
- (NSArray<NSString *> *)supportedEvents {
  return @[@"PhoneCallStateUpdate"];
}

// 响应旧架构 JS 侧的手动调用
RCT_EXPORT_METHOD(startListener) {
  // iOS 依靠 startObserving 自动管理，此处可以留空或进行初始化
}

RCT_EXPORT_METHOD(stopListener) {
  // iOS 依靠 stopObserving 自动管理
}

#pragma mark - CXCallObserverDelegate

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
  if (!hasListeners) {
    return;
  }

  NSString *state = @"Disconnected";

  if (call.hasConnected) {
    state = @"Connected";
  } else if (call.hasEnded) {
    state = @"Disconnected";
  } else if (call.isOutgoing) {
    state = @"Dialing"; // 拨号中
  } else {
    state = @"Incoming"; // 来电未接听
  }

  // 发送事件到 JS 侧
  [self sendEventWithName:@"PhoneCallStateUpdate" body:@{
    @"state": state,
    @"phoneNumber": @"" // iOS 限制，无法获取号码
  }];
}

@end
