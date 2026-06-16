package com.yourproject; // 请替换为你的实际包名

import android.content.Context;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class CallDetectorModule extends ReactContextBaseJavaModule {
    private final ReactApplicationContext reactContext;
    private TelephonyManager telephonyManager;
    private PhoneStateListener phoneStateListener;
    private boolean isListening = false;

    public CallDetectorModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    @Override
    public String getName() {
        return "CallDetector";
    }

    private void sendEvent(String eventName, WritableMap params) {
        if (reactContext.hasActiveCatalystInstance()) {
            reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
        }
    }

    @ReactMethod
    public void startListener() {
        if (isListening) return;

        telephonyManager = (TelephonyManager) reactContext.getSystemService(Context.TELEPHONY_SERVICE);
        phoneStateListener = new PhoneStateListener() {
            @Override
            public void onCallStateChanged(int state, String incomingNumber) {
                WritableMap params = Arguments.createMap();
                switch (state) {
                    case TelephonyManager.CALL_STATE_IDLE:
                        params.putString("state", "Disconnected");
                        params.putString("phoneNumber", "");
                        sendEvent("PhoneCallStateUpdate", params);
                        break;
                    case TelephonyManager.CALL_STATE_OFFHOOK:
                        // 接通或拨出
                        params.putString("state", "Connected");
                        params.putString("phoneNumber", "");
                        sendEvent("PhoneCallStateUpdate", params);
                        break;
                    case TelephonyManager.CALL_STATE_RINGING:
                        // 来电
                        params.putString("state", "Incoming");
                        params.putString("phoneNumber", incomingNumber != null ? incomingNumber : "");
                        sendEvent("PhoneCallStateUpdate", params);
                        break;
                }
            }
        };

        if (telephonyManager != null) {
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE);
            isListening = true;
        }
    }

    @ReactMethod
    public void stopListener() {
        if (telephonyManager != null && phoneStateListener != null) {
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE);
            isListening = false;
        }
    }

    // 为了兼容旧架构的某些生命周期，建议在清除时也注销监听
    @Override
    public void onCatalystInstanceDestroy() {
        super.onCatalystInstanceDestroy();
        stopListener();
    }
}
