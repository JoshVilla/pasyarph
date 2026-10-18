import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Alerts shown while Google Maps is in front: arriving at the main stop,
/// leaving the loop, and finishing it.
abstract interface class RideNotifier {
  /// Asks for notification permission (Android 13+). Safe to call again.
  Future<void> prepare();
  Future<void> arrivedAtStop(String stopName);
  Future<void> leftLoop();

  /// Clears the [leftLoop] alert.
  Future<void> backOnLoop();

  /// Back home after the loop; the ride is still open until finished.
  Future<void> backHome();
  Future<void> rideFinished(String summary);

  /// Clears every ride alert (the ride is over).
  Future<void> clearAlerts();
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
      channelDescription:
          'Arriving at the main stop, leaving the loop, and finishing it',
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
  Future<void> leftLoop() => _plugin.show(
    id: 3,
    title: "You've left the loop",
    body: 'Google Maps took another road. Pull over to see the loop in Pasyar.',
    notificationDetails: _details,
  );

  @override
  Future<void> backOnLoop() => _plugin.cancel(id: 3);

  @override
  Future<void> backHome() => _plugin.show(
    id: 4,
    title: "You're back home",
    body: 'Open Pasyar and tap FINISH RIDE to save your loop.',
    notificationDetails: _details,
  );

  @override
  Future<void> clearAlerts() => _plugin.cancelAll();

  @override
  Future<void> rideFinished(String summary) => _plugin.show(
    id: 2,
    title: 'Loop done. Nice ride!',
    body: summary,
    notificationDetails: _details,
  );
}
