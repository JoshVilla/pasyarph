import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/app.dart';
import 'package:pasyarph/core/widgets/bottom_tabs.dart';
import 'package:pasyarph/features/create/screens/create_screen.dart';
import 'package:pasyarph/features/feed/screens/feed_screen.dart';
import 'package:pasyarph/features/me/screens/me_screen.dart';
import 'package:pasyarph/features/ride/screens/ride_screen.dart';

void main() {
  testWidgets('starts on Ride and switches between the four tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const PasyarApp());
    await tester.pumpAndSettle();

    expect(find.byType(RideScreen), findsOneWidget);

    final tabs = {
      'Feed': FeedScreen,
      'Create': CreateScreen,
      'Me': MeScreen,
      'Ride': RideScreen,
    };
    for (final MapEntry(key: label, value: screen) in tabs.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(PasyarBottomTabs),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: label);
    }
  });
}
