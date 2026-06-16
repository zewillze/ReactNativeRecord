import { 
  NativeEventEmitter, 
  NativeModules, 
  Platform,
  PermissionsAndroid,
} from 'react-native';

const { PhoneStateModule } = NativeModules;

/**
 * 电话事件类型
 */
export type PhoneEventType =
  | 'incoming'    // 来电响铃
  | 'answered'    // 已接听（通话中）
  | 'ended'       // 通话结束
  | 'missed'      // 未接来电
  | 'outgoing';   // 拨出电话 (iOS only)

/**
 * 电话事件数据
 */
export interface PhoneEventData {
  /** 事件类型 */
  eventType: PhoneEventType;
  /** 电话号码（Android 可获取，iOS 为 unknown） */
  phoneNumber: string;
  /** 是否是来电 */
  isIncoming: boolean;
}

/**
 * 监听器回调函数类型
 */
export type PhoneEventListenerCallback = (event: PhoneEventData) => void;

/**
 * 电话状态模块接口（Android 使用 Callback 模式）
 */
interface IPhoneStateModule {
  startListening(callback: (error?: string | null, result?: boolean) => void): void;
  stopListening(callback: (error?: string | null, result?: boolean) => void): void;
  isListening(callback: (error: null, result: boolean) => void): void;
  getCurrentState(callback: (error: null, state: { state: string }) => void): void;
  hasPermission(callback: (granted: boolean) => void): void; // Android only
  // 测试方法（仅 Debug 模式）
  simulateEvent?(eventType: string, phoneNumber: string, isIncoming: boolean, callback?: (result: any) => void): void;
  simulateIncomingCall?(phoneNumber: string, callback?: (result: any) => void): void;
  simulateMissedCall?(phoneNumber: string, callback?: (result: any) => void): void;
}

class PhoneStateManager {
  private eventEmitter: NativeEventEmitter | null = null;
  private listeners: Map<PhoneEventListenerCallback, any> = new Map();
  private _isListening: boolean = false;

  constructor() {
    if (PhoneStateModule) {
      this.eventEmitter = new NativeEventEmitter(PhoneStateModule);
    }
  }

  /**
   * 开始监听电话事件
   */
  startListening(): Promise<boolean> {
    if (!PhoneStateModule) {
      console.warn('[PhoneState] Module is not available on this platform');
      return Promise.resolve(false);
    }

    return new Promise((resolve, reject) => {
      PhoneStateModule.startListening((error?: string | null, result?: boolean) => {
        if (error) {
          console.error('[PhoneState] Failed to start listening:', error);
          reject(new Error(error));
        } else {
          this._isListening = result || false;
          resolve(result || false);
        }
      });
    });
  }

  /**
   * 停止监听电话事件
   */
  stopListening(): Promise<boolean> {
    if (!PhoneStateModule) {
      return Promise.resolve(true);
    }

    return new Promise((resolve, reject) => {
      PhoneStateModule.stopListening((error?: string | null, result?: boolean) => {
        if (error) {
          console.error('[PhoneState] Failed to stop listening:', error);
          reject(new Error(error));
        } else {
          this._isListening = false;
          // 移除所有监听器
          this.removeAllListeners();
          resolve(result || true);
        }
      });
    });
  }

  /**
   * 是否正在监听
   */
  isListening(): Promise<boolean> {
    if (!PhoneStateModule) {
      return Promise.resolve(this._isListening);
    }

    return new Promise((resolve) => {
      PhoneStateModule.isListening((_error: null, result: boolean) => {
        resolve(result);
      });
    });
  }

  /**
   * 获取当前通话状态
   */
  getCurrentState(): Promise<{ state: string }> {
    if (!PhoneStateModule) {
      return Promise.resolve({ state: 'unknown' });
    }

    return new Promise((resolve) => {
      PhoneStateModule.getCurrentState((_error: null, state: { state: string }) => {
        resolve(state);
      });
    });
  }

  /**
   * 检查是否有权限
   */
  checkPermission(): Promise<boolean> {
    if (Platform.OS === 'ios') {
      return Promise.resolve(true); // iOS 不需要特殊权限
    }

    if (Platform.OS === 'android') {
      // 使用 PermissionsAndroid 检查运行时权限
      return PermissionsAndroid.check(PermissionsAndroid.PERMISSIONS.READ_PHONE_STATE);
    }

    if (!PhoneStateModule) {
      return Promise.resolve(false);
    }

    return new Promise((resolve) => {
      try {
        PhoneStateModule.hasPermission((granted: boolean) => resolve(granted));
      } catch (error) {
        console.error('[PhoneState] Failed to check permission:', error);
        resolve(false);
      }
    });
  }

  /**
   * 请求运行时权限（仅 Android）
   * 返回值：
   * - true: 权限已授予
   * - false: 权限被拒绝
   */
  async requestPermission(): Promise<boolean> {
    if (Platform.OS === 'ios') {
      return true; // iOS 不需要特殊权限
    }

    if (Platform.OS !== 'android') {
      return false;
    }

    try {
      // 先检查是否已有权限
      const granted = await PermissionsAndroid.check(
        PermissionsAndroid.PERMISSIONS.READ_PHONE_STATE
      );
      
      if (granted) {
        console.log('[PhoneState] Permission already granted');
        return true;
      }

      // 请求权限
      const result = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.READ_PHONE_STATE,
        {
          title: '电话状态访问权限',
          message: '应用需要读取电话状态权限来监听来电和通话事件',
          buttonNeutral: '稍后再问',
          buttonNegative: '拒绝',
          buttonPositive: '允许',
        }
      );

      console.log('[PhoneState] Permission request result:', result);

      switch (result) {
        case PermissionsAndroid.RESULTS.GRANTED:
          console.log('[PhoneState] Permission granted');
          return true;
        case PermissionsAndroid.RESULTS.DENIED:
          console.log('[PhoneState] Permission denied by user');
          return false;
        case PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN:
          console.log('[PhoneState] User selected "Never Ask Again"');
          return false;
        default:
          console.log('[PhoneState] Unknown permission result:', result);
          return false;
      }
    } catch (err) {
      console.warn('[PhoneState] Error requesting permission:', err);
      return false;
    }
  }

  /**
   * 添加事件监听器
   */
  addListener(callback: PhoneEventListenerCallback): () => void {
    if (!this.eventEmitter || !PhoneStateModule) {
      console.warn('[PhoneState] Cannot add listener - module not available');
      return () => {};
    }

    // 防止重复添加
    if (this.listeners.has(callback)) {
      return () => this.removeListener(callback);
    }

    const subscription = this.eventEmitter.addListener(
      'phoneStateChanged',
      (event: PhoneEventData) => {
        console.log(`[PhoneState] Event received: ${event.eventType}`, event);
        callback(event);
      }
    );

    this.listeners.set(callback, subscription);

    // 返回取消订阅函数
    return () => this.removeListener(callback);
  }

  /**
   * 移除指定监听器
   */
  removeListener(callback: PhoneEventListenerCallback): void {
    const subscription = this.listeners.get(callback);
    if (subscription) {
      subscription.remove();
      this.listeners.delete(callback);
    }
  }

  /**
   * 移除所有监听器
   */
  removeAllListeners(): void {
    this.listeners.forEach((subscription) => subscription.remove());
    this.listeners.clear();
  }

  // MARK: - 测试方法（仅用于开发调试）

  /**
   * 模拟单个电话事件（仅 Debug 模式可用）
   */
  async simulateEvent(
    eventType: PhoneEventType,
    phoneNumber: string = '13800138000',
    isIncoming: boolean = true,
  ): Promise<{ success: boolean; eventSent: string }> {
    if (!PhoneStateModule || !PhoneStateModule.simulateEvent) {
      console.warn('[PhoneState] simulateEvent not available on this platform');
      return Promise.resolve({ success: false, eventSent: '' });
    }

    return new Promise((resolve, reject) => {
      PhoneStateModule.simulateEvent!(
        eventType,
        phoneNumber,
        isIncoming,
        (result: any) => resolve(result),
      );
    });
  }

  /**
   * 模拟完整来电流程：incoming → answered → ended
   */
  async simulateIncomingCall(
    phoneNumber: string = '13800138000',
  ): Promise<{ success: boolean; message: string }> {
    if (!PhoneStateModule || !PhoneStateModule.simulateIncomingCall) {
      console.warn('[PhoneState] simulateIncomingCall not available on this platform');
      return Promise.resolve({ success: false, message: 'Not available' });
    }

    return new Promise((resolve, reject) => {
      PhoneStateModule.simulateIncomingCall!(phoneNumber, (result: any) => resolve(result));
    });
  }

  /**
   * 模拟未接来电流程：incoming → missed
   */
  async simulateMissedCall(
    phoneNumber: string = '13800138000',
  ): Promise<{ success: boolean; message: string }> {
    if (!PhoneStateModule || !PhoneStateModule.simulateMissedCall) {
      console.warn('[PhoneState] simulateMissedCall not available on this platform');
      return Promise.resolve({ success: false, message: 'Not available' });
    }

    return new Promise((resolve, reject) => {
      PhoneStateModule.simulateMissedCall!(phoneNumber, (result: any) => resolve(result));
    });
  }
}

// 导出单例实例
export const phoneStateManager = new PhoneStateManager();

export default phoneStateManager;
