package com.nativespeed79.phone;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

/**
 * 电话状态监听原生模块
 *
 * 支持事件：
 * - incoming: 来电（响铃中）
 * - answered: 已接听（通话中）
 * - ended: 通话结束（挂断）
 * - idle: 空闲状态
 */
public class PhoneStateModule extends ReactContextBaseJavaModule {

    public static final String MODULE_NAME = "PhoneStateModule";
    private static final String EVENT_NAME = "phoneStateChanged";

    private final ReactApplicationContext reactContext;
    private TelephonyManager telephonyManager;
    private CustomPhoneStateListener phoneStateListener;
    private boolean isListening = false;
    private String lastState = "idle";

    public PhoneStateModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        initTelephonyManager();
    }

    private void initTelephonyManager() {
        if (reactContext == null) return;
        telephonyManager = (TelephonyManager) reactContext.getSystemService(Context.TELEPHONY_SERVICE);
    }

    @NonNull
    @Override
    public String getName() {
        return MODULE_NAME;
    }

    /**
     * 开始监听电话状态变化
     */
    @ReactMethod
    public void startListening(Callback callback) {
        if (!hasPhonePermission()) {
            callback.invoke("Permission denied: READ_PHONE_STATE permission is required");
            return;
        }

        if (isListening) {
            callback.invoke(null, true); // Already listening
            return;
        }

        try {
            phoneStateListener = new CustomPhoneStateListener();
            if (telephonyManager != null) {
                // LISTEN_CALL_STATE 包含了所有通话相关的状态
                telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE);
                isListening = true;
                callback.invoke(null, true);
            } else {
                callback.invoke("TelephonyManager is not available");
            }
        } catch (Exception e) {
            callback.invoke("Error starting listener: " + e.getMessage());
        }
    }

    /**
     * 停止监听电话状态变化
     */
    @ReactMethod
    public void stopListening(Callback callback) {
        if (!isListening) {
            callback.invoke(null, true); // Already stopped
            return;
        }

        try {
            if (telephonyManager != null && phoneStateListener != null) {
                telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE);
                isListening = false;
                lastState = "idle";
                callback.invoke(null, true);
            } else {
                callback.invoke(null, true);
            }
        } catch (Exception e) {
            callback.invoke("Error stopping listener: " + e.getMessage());
        }
    }

    /**
     * 获取当前是否正在监听
     */
    @ReactMethod
    public void isListening(Callback callback) {
        callback.invoke(null, isListening);
    }

    /**
     * 获取当前通话状态
     */
    @ReactMethod
    public void getCurrentState(Callback callback) {
        WritableMap stateMap = Arguments.createMap();
        stateMap.putString("state", lastState);
        callback.invoke(null, stateMap);
    }

    /**
     * 检查是否有读取电话状态的权限
     */
    @ReactMethod
    public void hasPermission(Callback callback) {
        callback.invoke(null, hasPhonePermission());
    }

    private boolean hasPhonePermission() {
        if (reactContext == null) return false;
        return ActivityCompat.checkSelfPermission(
                reactContext,
                Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED ||
               ActivityCompat.checkSelfPermission(
                reactContext,
                Manifest.permission.READ_PHONE_NUMBERS
        ) == PackageManager.PERMISSION_GRANTED;
    }

    /**
     * 发送事件到 JavaScript
     */
    private void sendEvent(String eventType, String phoneNumber, boolean isIncoming) {
        if (!reactContext.hasActiveCatalystInstance()) return;

        WritableMap params = Arguments.createMap();
        params.putString("eventType", eventType);
        params.putString("phoneNumber", phoneNumber != null ? phoneNumber : "unknown");
        params.putBoolean("isIncoming", isIncoming);

        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(EVENT_NAME, params);
    }

    /**
     * 自定义 PhoneStateListener
     */
    private class CustomPhoneStateListener extends PhoneStateListener {

        private String currentCallNumber = "";
        private boolean wasRinging = false;

        @Override
        public void onCallStateChanged(int state, String phoneNumber) {
            switch (state) {
                case TelephonyManager.CALL_STATE_RINGING:
                    // 来电响铃
                    wasRinging = true;
                    currentCallNumber = phoneNumber != null ? phoneNumber : "";
                    lastState = "ringing";
                    sendEvent("incoming", currentCallNumber, true);
                    break;

                case TelephonyManager.CALL_STATE_OFFHOOK:
                    // 通话中（接听或拨打电话）
                    lastState = "offhook";
                    if (wasRinging) {
                        // 从响铃到通话中，说明是接听了来电
                        sendEvent("answered", currentCallNumber, true);
                    }
                    // 如果不是从响铃来的，可能是拨出电话
                    break;

                case TelephonyManager.CALL_STATE_IDLE:
                    // 空闲（挂断或无通话）
                    String previousState = lastState;
                    lastState = "idle";
                    if ("ringing".equals(previousState)) {
                        // 从响铃直接到空闲，说明未接听就挂断了
                        sendEvent("missed", currentCallNumber, true);
                    } else if ("offhook".equals(previousState)) {
                        // 从通话中到空闲，说明通话结束
                        sendEvent("ended", currentCallNumber, wasRinging);
                    }

                    // 重置状态
                    currentCallNumber = "";
                    wasRinging = false;
                    break;

                default:
                    break;
            }
        }
    }

    // MARK: - 测试方法（仅用于开发调试）

    /**
     * 模拟单个电话事件（仅 Debug 模式可用）
     */
    @ReactMethod
    public void simulateEvent(String eventType, String phoneNumber, boolean isIncoming, Callback callback) {
        if (!isListening) {
            callback.invoke("Please start listening first", null);
            return;
        }

        sendEvent(eventType, phoneNumber, isIncoming);
        callback.invoke(null, true);
    }

    /**
     * 模拟完整来电流程：incoming → answered → ended（仅 Debug 模式可用）
     */
    @ReactMethod
    public void simulateIncomingCall(String phoneNumber, Callback callback) {
        if (!isListening) {
            callback.invoke("Please start listening first", null);
            return;
        }

        // 使用 Handler 延迟发送事件
        android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());

        // 1. 来电响铃 (500ms)
        handler.postDelayed(() -> {
            sendEvent("incoming", phoneNumber, true);
            
            // 2. 接听 (3.5s)
            handler.postDelayed(() -> {
                sendEvent("answered", phoneNumber, true);
                
                // 3. 挂断 (8.5s)
                handler.postDelayed(() -> {
                    sendEvent("ended", phoneNumber, true);
                }, 5000);
            }, 3000);
        }, 500);

        callback.invoke(null, true);
    }

    /**
     * 模拟未接来电流程：incoming → missed（仅 Debug 模式可用）
     */
    @ReactMethod
    public void simulateMissedCall(String phoneNumber, Callback callback) {
        if (!isListening) {
            callback.invoke("Please start listening first", null);
            return;
        }

        android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());

        // 1. 来电响铃 (500ms)
        handler.postDelayed(() -> {
            sendEvent("incoming", phoneNumber, true);
            
            // 2. 未接 (4.5s)
            handler.postDelayed(() -> {
                sendEvent("missed", phoneNumber, true);
            }, 4000);
        }, 500);

        callback.invoke(null, true);
    }
}
