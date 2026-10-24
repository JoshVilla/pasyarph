import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/notifications/ride_notifier.dart';
import 'package:pasyarph/core/notifications/voice_ride_notifier.dart';
import 'package:pasyarph/core/settings/app_settings.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/me_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/me/me_rules.dart';
import 'package:pasyarph/features/me/providers/me_controller.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_me.dart';
import '../../support/fake_services.dart';

final _now = DateTime(2026, 10, 24, 9);

RideSummary _ride({
  required double riddenM,
  int loopM = 40000,
  bool synced = false,
  String? id,
}) => RideSummary(
  id: id ?? newId(),
  startedAt: _now.subtract(const Duration(hours: 3)),
  endedAt: _now,
  riddenM: riddenM,
  loopM: loopM,
  reachedStop: true,
  synced: synced,
);

class _Speaker implements Speaker {
  final said = <String>[];

  @override
  Future<void> speak(String text) async => said.add(text);
}

class _Notifier implements RideNotifier {
  final calls = <String>[];

  @override
  Future<void> prepare() async => calls.add('prepare');
  @override
  Future<void> arrivedAtStop(String stopName) async =>
      calls.add('stop:$stopName');
  @override
  Future<void> leftLoop() async => calls.add('left');
  @override
  Future<void> backOnLoop() async => calls.add('back');
  @override
  Future<void> backHome() async => calls.add('home');
  @override
  Future<void> rideFinished(String summary) async => calls.add('done');
  @override
  Future<void> clearAlerts() async => calls.add('clear');
}

void main() {
  group('totals', () {
    const server = RiderTotals(riddenM: 120000, loopsRidden: 3, posts: 2);

    test('rides waiting to sync are added', () {
      final totals = withUnsyncedRides(server, [
        _ride(riddenM: 41000.4),
        // Turned back early: km count, the loop doesn't.
        _ride(riddenM: 5000),
        // Already in the server's numbers.
        _ride(riddenM: 99000, synced: true),
        // Saved before syncing existed: never syncs, never counted.
        _ride(riddenM: 30000, id: ''),
      ]);
      expect(
        totals,
        const RiderTotals(riddenM: 166000, loopsRidden: 4, posts: 2),
      );
    });

    test('formatTotalKm', () {
      expect(formatTotalKm(0), '0');
      expect(formatTotalKm(8400), '8.4');
      expect(formatTotalKm(128400), '128');
      expect(formatTotalKm(1234500), '1,235');
      expect(formatTotalKm(12345678), '12,346');
    });

    test('postsOnly drops loops shared without a post', () {
      final items = [
        feedPost(id: 'p1', createdAt: _now),
        feedPost(id: 'l1', createdAt: _now, loopOnly: true),
      ];
      expect(postsOnly(items).map((p) => p.id), ['p1']);
    });

    test('RiderTotals reads my_totals() rows', () {
      expect(
        RiderTotals.fromJson({
          'ridden_m': 46000,
          'loops_ridden': 1,
          'posts': 2,
        }),
        const RiderTotals(riddenM: 46000, loopsRidden: 1, posts: 2),
      );
    });
  });

  group('MeController', () {
    test('totals update right after a ride, before it syncs', () async {
      final history = FakeRideHistory();
      final me = FakeMeRepository(
        serverTotals: const RiderTotals(
          riddenM: 10000,
          loopsRidden: 1,
          posts: 0,
        ),
      );
      final c = MeController(
        me: me,
        feed: FakeFeedRepository(const []),
        rides: history,
        userId: 'user-1',
      );
      await c.load();
      expect(c.totals.riddenM, 10000);
      expect(c.posts, isEmpty);

      await history.save(_ride(riddenM: 40000));
      await pumpEventQueue();
      expect(
        c.totals,
        const RiderTotals(riddenM: 50000, loopsRidden: 2, posts: 0),
      );
      c.dispose();
    });

    test('loads the rider\'s posts, not their shared loops', () async {
      final c = MeController(
        me: FakeMeRepository(),
        feed: FakeFeedRepository(
          const [],
          scoped: {
            const FeedScope.rider('user-1'): [
              feedPost(id: 'p1', createdAt: _now),
              feedPost(id: 'l1', createdAt: _now, loopOnly: true),
            ],
          },
        ),
        rides: FakeRideHistory(),
        userId: 'user-1',
      );
      await c.load();
      expect(c.posts!.map((p) => p.id), ['p1']);
      c.dispose();
    });

    test('offline: shows why, keeps what was loaded', () async {
      final me = FakeMeRepository()..fail = true;
      final c = MeController(
        me: me,
        feed: FakeFeedRepository(const [])..fail = true,
        rides: FakeRideHistory(),
        userId: 'user-1',
      );
      await c.load();
      expect(c.error, MeException.loadFailed.message);
      expect(c.posts, isNull);
      c.dispose();
    });
  });

  group('settings and voice prompts', () {
    test('voice prompts are on by default and remembered', () async {
      final store = MemorySettingsStore();
      final settings = AppSettings(store);
      await settings.load();
      expect(settings.voicePrompts, isTrue);

      await settings.setVoicePrompts(false);
      final again = AppSettings(store);
      await again.load();
      expect(again.voicePrompts, isFalse);
    });

    test('ride alerts are spoken only while voice prompts are on', () async {
      final settings = AppSettings(MemorySettingsStore());
      final speaker = _Speaker();
      final inner = _Notifier();
      final voice = VoiceRideNotifier(
        inner,
        settings: settings,
        speaker: speaker,
      );

      await voice.arrivedAtStop('Daranak Falls');
      await voice.leftLoop();
      await voice.backHome();
      expect(speaker.said, [
        'You made it to Daranak Falls. Pull over safely to take photos.',
        "You've left the loop.",
        "You're back home. Tap finish ride to save your loop.",
      ]);

      await settings.setVoicePrompts(false);
      await voice.rideFinished('82 km');
      expect(speaker.said, hasLength(3));
      // Notifications still show either way.
      expect(inner.calls, ['stop:Daranak Falls', 'left', 'home', 'done']);
    });
  });
}
