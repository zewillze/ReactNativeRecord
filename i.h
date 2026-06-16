#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <CallKit/CallKit.h>

@interface CallDetector : RCTEventEmitter <RCTBridgeModule, CXCallObserverDelegate>
@property (nonatomic, strong) CXCallObserver *callObserver;
@end
