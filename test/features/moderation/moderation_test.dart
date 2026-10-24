import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/core/settings/app_settings.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/me_repository.dart';
import 'package:pasyarph/data/repositories/moderation_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/me/screens/settings_screen.dart';
import 'package:pasyarph/features/moderation/moderation_rules.dart';
import 'package:pasyarph/features/moderation/screens/blocked_riders_screen.dart';
import 'package:pasyarph/features/moderation/screens/moderation_screen.dart';
import 'package:pasyarph/features/moderation/widgets/report_sheet.dart';
import 'package:pasyarph/features/ride/screens/ride_safety_screen.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_me.dart';
import '../../support/fake_moderation.dart';
import '../../support/fake_services.dart';

final _now = DateTime(2026, 10, 25, 9);
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

ReportedItem _item(
  String id,
  ReportTarget type, {
  int count = 1,
  List<String> reasons = const ['Spam or selling'],
  String? preview = 'Selling helmets, PM me',
  bool hidden = false,
}) => ReportedItem(
  targetType: type,
  targetId: id,
  reportCount: count,
  reasons: reasons,
  lastReportedAt: _now.subtract(const Duration(hours: 2)),
  isHidden: hidden,
  preview: preview,
  authorId: 'rico',
  authorName: 'Rico Navarro',
);

class _World {
  _World({bool moving = false, bool admin = false})
    : location = LocationProvider(
        permissions: FakeLocationPermission(),
        positions: FakePositionSource(
          last: RiderFix(point: DemoRoutes.start, speedMps: moving ? 8 : 0),
        ),
      ),
      moderation = FakeModerationRepository(
        admin: admin,
        names: {'rico': 'Rico Navarro', 'jun': 'Jun Mendoza'},
        queue: [
          _item(
            'p1',
            ReportTarget.post,
            count: 3,
            reasons: [
              'Spam or selling',
              'Spam or selling',
              'Something else: fake photos',
            ],
          ),
          _item(
            'c1',
            ReportTarget.comment,
            preview: 'Bobo mo naman',
            reasons: ['Harassment or hate'],
          ),
          _item('l1', ReportTarget.loop, preview: null, hidden: true),
        ],
      );

  final LocationProvider location;
  final FakeModerationRepository moderation;
  final settings = AppSettings(MemorySettingsStore());

  Widget app(String initial, {Widget? home}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => home ?? const Scaffold(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: Routes.blockedRiders,
          builder: (context, state) => const BlockedRidersScreen(),
        ),
        GoRoute(
          path: Routes.moderation,
          builder: (context, state) => ModerationScreen(clock: () => _now),
        ),
        GoRoute(
          path: Routes.rideSafety,
          builder: (context, state) => const RideSafetyScreen(),
        ),
      ],
    );
    return MultiProvider(
      providers: [
        Provider<ModerationRepository>.value(value: moderation),
        Provider<MeRepository>(create: (_) => FakeMeRepository()),
        Provider<FeedRepository>(create: (_) => FakeFeedRepository(const [])),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

Future<_World> _pump(
  WidgetTester tester,
  String initial, {
  _World? world,
  Widget? home,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final w = world ?? _World();
  await w.location.start();
  await tester.pumpWidget(w.app(initial, home: home));
  await tester.pumpAndSettle();
  return w;
}

/// A page with a button that opens the report sheet for a post by Rico.
Widget _reportButton(void Function(ReportResult?) done) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: PrimaryButton(
        label: 'OPEN',
        onPressed: () async => done(
          await showReportSheet(
            context,
            const ReportSubject(
              target: ReportTarget.post,
              id: 'p1',
              what: 'post',
              authorId: 'rico',
              authorName: 'Rico',
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('rules', () {
    test('report reasons as moderators read them', () {
      expect(reportReasonText(ReportReason.spam, '  '), 'Spam or selling');
      expect(
        reportReasonText(ReportReason.other, ' fake\n  photos '),
        'Something else: fake photos',
      );
      expect(
        reportReasonText(ReportReason.other, 'x' * 600).length,
        maxReportReason,
      );
      expect(reportNeedsDetails(ReportReason.other, 'no'), isTrue);
      expect(reportNeedsDetails(ReportReason.other, 'fake photos'), isFalse);
      expect(reportNeedsDetails(ReportReason.spam, ''), isFalse);
    });

    test('summarizeReasons counts and caps', () {
      expect(summarizeReasons(['A', 'B', 'A', 'C', 'D', 'A']), [
        'A ×3',
        'B',
        'C',
        '+ 1 more',
      ]);
    });
  });

  group('Golden', () {
    // No mockups: built from DESIGN.md components (sheet, choice cards,
    // safety rows) like onboarding (11) and Create (06).
    goldenTest(
      'Report sheet',
      fileName: 'report_sheet',
      constraints: _screen,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SPAM OR SELLING'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final w = _World();
        w.location.start();
        return w.app('/home', home: _reportButton((_) {}));
      },
    );
    goldenTest(
      'Moderation queue',
      fileName: 'moderation_queue',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () {
        final w = _World(admin: true);
        w.location.start();
        return w.app(Routes.moderation);
      },
    );
    goldenTest(
      'First-ride safety',
      fileName: 'ride_safety',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () {
        final w = _World();
        w.location.start();
        return w.app(Routes.rideSafety);
      },
    );
  });

  group('report sheet', () {
    testWidgets('pick a reason, send; optionally block the rider too', (
      tester,
    ) async {
      ReportResult? result;
      final w = await _pump(
        tester,
        '/home',
        home: _reportButton((r) => result = r),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('REPORT POST'), findsOneWidget);

      PrimaryButton send() => tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'SEND REPORT'),
      );
      expect(send().onPressed, isNull);

      await tester.tap(find.text('NUDITY OR VIOLENCE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Also block Rico'));
      await tester.tap(find.text('Also block Rico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(w.moderation.reports, [
        (ReportTarget.post, 'p1', 'Nudity or violence'),
      ]);
      expect(w.moderation.blockedIds, ['rico']);
      expect(result?.blocked, isTrue);
    });

    testWidgets('"Something else" needs a few words', (tester) async {
      await _pump(tester, '/home', home: _reportButton((_) {}));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SOMETHING ELSE'));
      await tester.tap(find.text('SOMETHING ELSE'));
      await tester.pumpAndSettle();
      PrimaryButton send() => tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'SEND REPORT'),
      );
      expect(send().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Fake photos');
      await tester.pumpAndSettle();
      expect(send().onPressed, isNotNull);
    });

    testWidgets('no sending or typing while riding', (tester) async {
      await _pump(
        tester,
        '/home',
        world: _World(moving: true),
        home: _reportButton((_) {}),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SPAM OR SELLING'));
      await tester.pumpAndSettle();
      expect(find.text('Stop riding to send a report.'), findsOneWidget);
      expect(find.text('Stop riding to type.'), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'SEND REPORT'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('blocking', () {
    testWidgets('blocked riders can be unblocked from Settings', (
      tester,
    ) async {
      final w = _World();
      await w.moderation.block('rico');
      await w.moderation.block('jun');
      await _pump(tester, Routes.settings, world: w);
      await tester.ensureVisible(find.text('BLOCKED RIDERS'));
      await tester.tap(find.text('BLOCKED RIDERS'));
      await tester.pumpAndSettle();
      expect(find.text('Rico Navarro'), findsOneWidget);
      expect(find.text('Jun Mendoza'), findsOneWidget);

      await tester.tap(find.text('UNBLOCK').first);
      await tester.pumpAndSettle();
      expect(w.moderation.blockedIds, ['rico']);
      expect(find.text('Jun Mendoza'), findsNothing);
      expect(find.text('Jun Mendoza is unblocked.'), findsOneWidget);
    });
  });

  group('moderation', () {
    testWidgets('only admins see REVIEW REPORTS', (tester) async {
      await _pump(tester, Routes.settings);
      expect(find.text('REVIEW REPORTS'), findsNothing);

      await _pump(tester, Routes.settings, world: _World(admin: true));
      await tester.ensureVisible(find.text('REVIEW REPORTS'));
      await tester.tap(find.text('REVIEW REPORTS'));
      await tester.pumpAndSettle();
      expect(find.byType(ModerationScreen), findsOneWidget);
    });

    testWidgets('the queue: what, whose, why', (tester) async {
      await _pump(tester, Routes.moderation, world: _World(admin: true));
      expect(find.text('POST · 3 REPORTS'), findsOneWidget);
      expect(find.text('• Spam or selling ×2'), findsOneWidget);
      expect(find.text('• Something else: fake photos'), findsOneWidget);
      expect(find.text('Bobo mo naman'), findsOneWidget);
      expect(
        find.text('By Rico Navarro · Last reported 2 h ago'),
        findsWidgets,
      );
    });

    testWidgets('HIDE and DISMISS close the reports; UNHIDE shows it', (
      tester,
    ) async {
      final w = await _pump(
        tester,
        Routes.moderation,
        world: _World(admin: true),
      );
      await tester.tap(find.text('HIDE').first);
      await tester.pumpAndSettle();
      expect(find.text('Hidden. Reports closed.'), findsOneWidget);
      expect(find.text('POST · 3 REPORTS'), findsNothing);

      await tester.tap(find.text('DISMISS').first);
      await tester.pumpAndSettle();
      expect(find.text('Bobo mo naman'), findsNothing);

      // The hidden loop (deleted since) can be shown again.
      expect(find.text('LOOP · 1 REPORT · HIDDEN'), findsOneWidget);
      await tester.tap(find.text('UNHIDE'));
      await tester.pumpAndSettle();
      expect(find.text('LOOP · 1 REPORT'), findsOneWidget);

      expect(w.moderation.moderated, [
        (ReportTarget.post, 'p1', ModerationAction.hide),
        (ReportTarget.comment, 'c1', ModerationAction.dismiss),
        (ReportTarget.loop, 'l1', ModerationAction.unhide),
      ]);
    });
  });

  group('first ride safety', () {
    testWidgets("LET'S RIDE remembers it; Back doesn't", (tester) async {
      bool? ready;
      final w = _World();
      await _pump(
        tester,
        '/home',
        world: w,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: PrimaryButton(
                label: 'START',
                onPressed: () async =>
                    ready = await context.push<bool>(Routes.rideSafety),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      expect(find.text('Mount your phone'), findsNothing); // in a Text.rich
      expect(find.byType(SafetyRow), findsNWidgets(5));
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(ready, isFalse);
      expect(w.settings.firstRideSafetySeen, isFalse);

      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("GOT IT, LET'S RIDE"));
      await tester.pumpAndSettle();
      expect(ready, isTrue);
      expect(w.settings.firstRideSafetySeen, isTrue);
    });
  });

  testWidgets('every PasyarTextField locks while moving', (tester) async {
    final w = _World(moving: true);
    await w.location.start();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: w.location,
        child: const MaterialApp(
          home: Scaffold(body: PasyarTextField(label: 'Email')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Stop riding to type.'), findsOneWidget);
  });
}
