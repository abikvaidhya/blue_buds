import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {},
    );
    _initialized = true;
  }

  Future<void> showConnectionRequest({
    required String peerName,
    required String peerId,
  }) async {
    await _plugin.show(
      id: peerId.hashCode,
      title: 'Connection request',
      body: '$peerName wants to chat',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'conn_req',
          'Connection Requests',
          channelDescription: 'Incoming BlueBuds connection requests',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'conn:$peerId',
    );
  }

  Future<void> showSavedNearby({
    required String peerName,
    required String peerId,
  }) async {
    await _plugin.show(
      id: peerId.hashCode + 1,
      title: 'Saved device nearby',
      body: '$peerName is in range',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'saved_near',
          'Saved Devices Nearby',
          channelDescription: 'When a saved BlueBuds device is nearby',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'saved:$peerId',
    );
  }

  Future<void> showNewMessage({
    required String peerName,
    required String preview,
  }) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: peerName,
      body: preview,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'New BlueBuds messages',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
