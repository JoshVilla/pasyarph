import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Alerts shown while Google Maps is in front: arriving at the main stop
/// and finishing the loop.
abstract interface class RideNotifier {
  /// Asks for notification permission (Android 13+). Safe to call again.
  Future<void> prepare();
  Future<void> arrivedAtStop(String stopName);
  Future<void> rideFinished(String summary);
}

class LocalRideNotifier implements RideNotifier {
  LocalRideNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'ride_alerts',
      'Ride alerts',
      channelDescription: 'Arriving at the main stop and finishing a loop',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> prepare() async {
    if (!_ready) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> arrivedAtStop(String stopName) => _plugin.show(
    id: 1,
    title: 'You made it to $stopName',
    body: 'Pull over safely, then open Pasyar to take photos.',
    notificationDetails: _details,
  );

  @override
  Future<void> rideFinished(String summary) => _plugin.show(
    id: 2,
    title: 'Loop done. Nice ride!',
    body: summary,
    notificationDetails: _details,
  );
}
