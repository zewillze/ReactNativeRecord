import React, { useEffect, useState, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Platform,
  Linking,
  SafeAreaView,
} from 'react-native';
import {
  phoneStateManager,
  PhoneEventData,
  PhoneEventType,
} from './PhoneStateModule';

interface LogEntry {
  id: number;
  timestamp: string;
  event: PhoneEventData;
}

const PhoneStateDemo: React.FC = () => {
  const [isListening, setIsListening] = useState(false);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [hasPermission, setHasPermission] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const logIdRef = useRef(0);

  // 检查初始权限
  useEffect(() => {
    checkPermission();
  }, []);

  // 添加日志
  const addLog = useCallback((event: PhoneEventData) => {
    const entry: LogEntry = {
      id: ++logIdRef.current,
      timestamp: new Date().toLocaleTimeString('zh-CN', {
        hour12: false,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      }),
      event,
    };

    setLogs(prev => [entry, ...prev].slice(0, 50)); // 保留最近 50 条
  }, []);

  // 检查权限
  const checkPermission = async () => {
    const granted = await phoneStateManager.checkPermission();
    setHasPermission(granted);
  };

  // 请求运行时权限
  const requestPermission = async () => {
    setIsLoading(true);
    
    try {
      const granted = await phoneStateManager.requestPermission();
      setHasPermission(granted);
      
      if (!granted && Platform.OS === 'android') {
        Alert.alert(
          '权限请求',
          '无法获取电话状态权限。\n\n请前往：设置 → 应用 → NativeSpeed79 → 权限，手动开启"电话"权限。',
          [
            { text: '取消', style: 'cancel' },
            { 
              text: '去设置', 
              onPress: () => Linking.openSettings() 
            },
          ]
        );
      }
    } catch (error) {
      console.error('Request permission error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // 切换监听状态
  const toggleListening = async () => {
    if (isListening) {
      const success = await phoneStateManager.stopListening();
      setIsListening(false);
      
      if (success) {
        addLog({
          eventType: 'ended' as PhoneEventType,
          phoneNumber: '',
          isIncoming: false,
        });
      }
    } else {
      // 先检查并请求权限
      let granted = await phoneStateManager.checkPermission();
      
      if (!granted) {
        granted = await phoneStateManager.requestPermission();
      }

      if (!granted && Platform.OS === 'android') {
        Alert.alert(
          '权限不足',
          '无法开始监听，请先授予电话状态权限。点击"请求权限"按钮尝试授权。',
          [{ text: '确定' }]
        );
        return;
      }

      const success = await phoneStateManager.startListening();
      setIsListening(success);

      if (success) {
        addLog({
          eventType: 'ringing' as PhoneEventType, // 用 ringing 表示开始监听
          phoneNumber: '',
          isIncoming: true,
        });
      }
    }
  };

  // MARK: - 测试方法处理函数

  // 模拟单个事件
  const handleSimulate = async (eventType: PhoneEventType) => {
    if (!isListening) return;

    try {
      const result = await phoneStateManager.simulateEvent(
        eventType,
        '13800138000',
        true,
      );
      
      if (!result.success) {
        Alert.alert('提示', '模拟失败，请确保在 Debug 模式下运行');
      }
    } catch (error) {
      console.error('Simulate error:', error);
    }
  };

  // 模拟完整来电流程
  const handleSimulateFullCall = async () => {
    if (!isListening) return;

    try {
      const result = await phoneStateManager.simulateIncomingCall('13912345678');
      
      if (result.success) {
        Alert.alert(
          '📞 模拟来电开始',
          '将按以下顺序触发事件：\n1. incoming (0.5s)\n2. answered (3.5s)\n3. ended (8.5s)',
          [{ text: '确定' }]
        );
      }
    } catch (error) {
      console.error('Simulate call error:', error);
    }
  };

  // 模拟未接来电流程
  const handleSimulateMissedCall = async () => {
    if (!isListening) return;

    try {
      const result = await phoneStateManager.simulateMissedCall('13766668888');
      
      if (result.success) {
        Alert.alert(
          '🔕 模拟未接来电开始',
          '将按以下顺序触发事件：\n1. incoming (0.5s)\n2. missed (4.5s)',
          [{ text: '确定' }]
        );
      }
    } catch (error) {
      console.error('Simulate missed call error:', error);
    }
  };

  // 注册事件监听器
  useEffect(() => {
    if (!isListening) return;

    const unsubscribe = phoneStateManager.addListener((event: PhoneEventData) => {
      addLog(event);
    });

    return () => {
      unsubscribe();
    };
  }, [isListening, addLog]);

  // 组件卸载时清理
  useEffect(() => {
    return () => {
      phoneStateManager.stopListening();
    };
  }, []);

  // 获取事件类型的显示文本和颜色
  const getEventDisplay = (eventType: PhoneEventType): { text: string; color: string; bg: string } => {
    switch (eventType) {
      case 'incoming':
        return { text: '📱 来电', color: '#FF9800', bg: '#FFF3E0' };
      case 'answered':
        return { text: '✅ 接听', color: '#4CAF50', bg: '#E8F5E9' };
      case 'ended':
        return { text: '❌ 结束', color: '#F44336', bg: '#FFEBEE' };
      case 'missed':
        return { text: '🔕 未接', color: '#9E9E9E', bg: '#F5F5F5' };
      case 'outgoing':
        return { text: '📞 拨出', color: '#2196F3', bg: '#E3F2FD' };
      default:
        return { text: eventType, color: '#000', bg: '#FFF' };
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* 头部 */}
      <View style={styles.header}>
        <Text style={styles.title}>📞 电话状态监听</Text>
        <View style={styles.statusContainer}>
          <View style={[styles.statusDot, { backgroundColor: isListening ? '#4CAF50' : '#999' }]} />
          <Text style={[styles.statusText, { color: isListening ? '#4CAF50' : '#999' }]}>
            {isListening ? '正在监听...' : '未监听'}
          </Text>
        </View>
      </View>

      {/* 控制面板 */}
      <View style={styles.controlPanel}>
        <TouchableOpacity
          style={[
            styles.button,
            styles.mainButton,
            { backgroundColor: isListening ? '#FF5252' : '#4CAF50' },
            isLoading && styles.buttonDisabled,
          ]}
          onPress={toggleListening}
          disabled={isLoading}
          activeOpacity={0.7}
        >
          <Text style={styles.buttonText}>
            {isLoading ? '⏳ 请稍候...' : (isListening ? '停止监听' : '开始监听')}
          </Text>
        </TouchableOpacity>

        <View style={styles.permissionRow}>
          <TouchableOpacity
            style={[
              styles.button,
              styles.secondaryButton,
              hasPermission && styles.grantedButton,
            ]}
            onPress={requestPermission}
            disabled={hasPermission || isLoading}
            activeOpacity={0.7}
          >
            <Text style={[
              styles.buttonText,
              styles.secondaryButtonText,
              hasPermission && styles.grantedButtonText,
            ]}>
              {isLoading ? '请求中...' : (hasPermission ? '✅ 已授权' : '🔐 请求权限')}
            </Text>
          </TouchableOpacity>
          
          <TouchableOpacity
            style={[styles.button, styles.smallButton]}
            onPress={checkPermission}
            activeOpacity={0.7}
          >
            <Text style={[styles.buttonText, styles.secondaryButtonText]}>
              🔄 刷新
            </Text>
          </TouchableOpacity>
        </View>
        
        <Text style={styles.permissionStatus}>
          权限状态: {hasPermission ? '✅ 已获取 - 可以开始监听' : '❌ 未授权 - 点击"请求权限"按钮'}
        </Text>
      </View>

      {/* 平台信息 */}
      <View style={styles.infoPanel}>
        <Text style={styles.infoText}>平台: {Platform.OS.toUpperCase()}</Text>
        <Text style={styles.infoText}>支持的事件:</Text>
        <View style={styles.eventList}>
          <Text style={styles.eventItem}>• incoming - 来电响铃</Text>
          <Text style={styles.eventItem}>• answered - 接听/通话中</Text>
          <Text style={styles.eventItem}>• ended - 通话结束</Text>
          <Text style={styles.eventItem}>• missed - 未接来电</Text>
          {Platform.OS === 'ios' && (
            <Text style={styles.eventItem}>• outgoing - 拨出电话</Text>
          )}
        </View>
      </View>

      {/* 测试面板（仅 iOS 或调试模式） */}
      {(Platform.OS === 'ios' || __DEV__) && (
        <View style={[styles.infoPanel, styles.testPanel]}>
          <Text style={styles.testTitle}>🧪 模拟器测试工具</Text>
          
          <View style={styles.testRow}>
            <TouchableOpacity
              style={[styles.button, styles.testButton]}
              onPress={() => handleSimulate('incoming')}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>📱 来电</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.testButton]}
              onPress={() => handleSimulate('answered')}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>✅ 接听</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.testButton]}
              onPress={() => handleSimulate('ended')}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>❌ 结束</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.testButton]}
              onPress={() => handleSimulate('missed')}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>🔕 未接</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.testRow}>
            <TouchableOpacity
              style={[styles.button, styles.fullTestButton]}
              onPress={handleSimulateFullCall}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>📞 完整来电流程 (8s)</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.testRow}>
            <TouchableOpacity
              style={[styles.button, styles.fullMissedButton]}
              onPress={handleSimulateMissedCall}
              disabled={!isListening}
              activeOpacity={0.7}
            >
              <Text style={styles.testButtonText}>🔕 未接来电流程 (4s)</Text>
            </TouchableOpacity>
          </View>

          {!isListening && (
            <Text style={styles.testHint}>⚠️ 请先点击"开始监听"</Text>
          )}
        </View>
      )}

      {/* 日志区域 */}
      <View style={styles.logContainer}>
        <View style={styles.logHeader}>
          <Text style={styles.logTitle}>📋 事件日志</Text>
          <Text style={styles.logCount}>{logs.length} 条记录</Text>
        </View>

        {logs.length === 0 ? (
          <View style={styles.emptyLog}>
            <Text style={styles.emptyLogText}>
              {isListening 
                ? '等待电话事件...\n请尝试拨打或接听电话'
                : '点击"开始监听"按钮开始监听电话事件'
              }
            </Text>
          </View>
        ) : (
          <ScrollView style={styles.logScroll} showsVerticalScrollIndicator={false}>
            {logs.map(log => {
              const display = getEventDisplay(log.event.eventType);
              return (
                <View key={log.id} style={[styles.logItem, { backgroundColor: display.bg }]}>
                  <View style={styles.logItemHeader}>
                    <Text style={[styles.eventTypeText, { color: display.color }]}>
                      {display.text}
                    </Text>
                    <Text style={styles.timestampText}>{log.timestamp}</Text>
                  </View>
                  <View style={styles.logItemBody}>
                    <Text style={styles.detailText}>
                      号码: {log.event.phoneNumber || '未知'}
                    </Text>
                    <Text style={styles.detailText}>
                      类型: {log.event.isIncoming ? '来电' : '去电'}
                    </Text>
                  </View>
                </View>
              );
            })}
          </ScrollView>
        )}
      </View>

      {/* 底部提示 */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          ⚠️ 注意: iOS 使用 CallKit，部分信息可能受限
        </Text>
        <Text style={styles.footerText}>
          Android 需要运行时权限 READ_PHONE_STATE
        </Text>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    padding: 20,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
    alignItems: 'center',
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 10,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 6,
  },
  statusText: {
    fontSize: 14,
    fontWeight: '500',
  },
  controlPanel: {
    padding: 20,
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    marginTop: 10,
  },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 14,
    borderRadius: 25,
    minWidth: 140,
    alignItems: 'center',
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  mainButton: {
    flex: 1,
    marginRight: 10,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  secondaryButton: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1.5,
    borderColor: '#2196F3',
    flex: 1,
  },
  grantedButton: {
    backgroundColor: '#E8F5E9',
    borderColor: '#4CAF50',
  },
  smallButton: {
    minWidth: 70,
    marginLeft: 8,
  },
  secondaryButtonText: {
    color: '#2196F3',
  },
  grantedButtonText: {
    color: '#4CAF50',
  },
  permissionRow: {
    flexDirection: 'row',
    marginTop: 12,
    marginBottom: 4,
  },
  permissionStatus: {
    width: '100%',
    marginTop: 12,
    fontSize: 13,
    color: '#666666',
    textAlign: 'center',
  },
  infoPanel: {
    margin: 15,
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  infoText: {
    fontSize: 14,
    color: '#333333',
    marginBottom: 8,
    fontWeight: '500',
  },
  eventList: {
    marginLeft: 8,
  },
  eventItem: {
    fontSize: 13,
    color: '#666666',
    lineHeight: 20,
  },
  logContainer: {
    flex: 1,
    margin: 15,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    overflow: 'hidden',
  },
  logHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
    backgroundColor: '#FAFAFA',
  },
  logTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333333',
  },
  logCount: {
    fontSize: 13,
    color: '#999999',
  },
  emptyLog: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyLogText: {
    fontSize: 14,
    color: '#999999',
    textAlign: 'center',
    lineHeight: 22,
  },
  logScroll: {
    maxHeight: 300,
    padding: 12,
  },
  logItem: {
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 3,
    borderLeftColor: '#CCCCCC',
  },
  logItemHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  eventTypeText: {
    fontSize: 15,
    fontWeight: '600',
  },
  timestampText: {
    fontSize: 12,
    color: '#999999',
  },
  logItemBody: {
    flexDirection: 'row',
    gap: 16,
  },
  detailText: {
    fontSize: 13,
    color: '#666666',
  },
  footer: {
    padding: 16,
    alignItems: 'center',
  },
  footerText: {
    fontSize: 11,
    color: '#999999',
    textAlign: 'center',
    marginBottom: 4,
  },

  // 测试面板样式
  testPanel: {
    borderColor: '#FFB74D',
    backgroundColor: '#FFF8E1',
  },
  testTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#E65100',
    marginBottom: 12,
  },
  testRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 8,
    gap: 8,
  },
  testButton: {
    flex: 1,
    minWidth: 70,
    paddingVertical: 10,
    backgroundColor: '#FF9800',
    borderRadius: 8,
    elevation: 1,
    shadowColor: '#FF9800',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
  },
  fullTestButton: {
    width: '100%',
    paddingVertical: 12,
    backgroundColor: '#4CAF50',
    borderRadius: 10,
  },
  fullMissedButton: {
    width: '100%',
    paddingVertical: 12,
    backgroundColor: '#9E9E9E',
    borderRadius: 10,
  },
  testButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#FFFFFF',
    textAlign: 'center',
  },
  testHint: {
    marginTop: 8,
    fontSize: 12,
    color: '#F57C00',
    fontStyle: 'italic',
    textAlign: 'center',
  },
});

export default PhoneStateDemo;
