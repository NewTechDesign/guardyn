import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _initializationFailed = false;

  bool get _isSupported {
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux;
  }

  Future<void> initialize() async {
    if (_isInitialized || _initializationFailed) return;

    if (!_isSupported) {
      debugPrint(
        'NotificationService: Notifications not supported on this platform',
      );
      _isInitialized = true;
      return;
    }

    try {
      _notifications = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
        defaultIcon: AssetsLinuxIcon('assets/images/logo.svg'),
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notifications!.initialize();

      if (Platform.isAndroid) {
        try {
          await _notifications!
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        } catch (e) {
          debugPrint(
            'NotificationService: Failed to request Android permissions: $e',
          );
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      _initializationFailed = true;
      _notifications = null;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String messagePreview,
    String? conversationId,
  }) async {
    if (!_isInitialized && !_initializationFailed) await initialize();

    await _playNotificationSound();

    if (_notifications != null) {
      await _showSystemNotification(
        title: senderName,
        body: messagePreview,
        payload: conversationId,
      );
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Failed to play notification sound: $e');
    }
  }

  Future<void> _showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_notifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: false,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _notifications!.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
