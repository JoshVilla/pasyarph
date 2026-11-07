import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/widgets/widgets.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

double opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(MotionChange),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('changed state settles without replaying on ordinary rebuilds', (
    tester,
  ) async {
    Widget content(int value) =>
        host(MotionChange(value: value, child: Text('$value')));
    await tester.pumpWidget(content(0));
    expect(opacity(tester), 1);
    await tester.pumpWidget(content(1));
    expect(opacity(tester), lessThan(1));
    expect(find.text('0'), findsNothing);
    await tester.pump(const Duration(milliseconds: 90));
    final midway = opacity(tester);
    expect(midway, greaterThan(0.65));
    expect(midway, lessThan(1));
    await tester.pumpWidget(content(1));
    expect(opacity(tester), midway);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid changes retain only the current accessible action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var tapped = -1;
    Widget content(int value) => host(
      MotionChange(
        value: value,
        child: TextButton(
          onPressed: () => tapped = value,
          child: Text('Action $value'),
        ),
      ),
    );
    await tester.pumpWidget(content(0));
    for (var i = 1; i <= 4; i++) {
      await tester.pumpWidget(content(i));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.text('Action 3'), findsNothing);
    expect(find.bySemanticsLabel('Action 4'), findsOneWidget);
    await tester.tap(find.text('Action 4'));
    expect(tapped, 4);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('content changes preserve input text and focus', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Widget content(int value) => host(
      MotionChange(
        value: value,
        child: TextField(controller: controller, focusNode: focus),
      ),
    );
    await tester.pumpWidget(content(0));
    await tester.enterText(find.byType(TextField), 'Ride draft');
    focus.requestFocus();
    await tester.pump();
    final fieldState = tester.state(find.byType(TextField));
    await tester.pumpWidget(content(1));
    expect(controller.text, 'Ride draft');
    expect(focus.hasFocus, isTrue);
    expect(tester.state(find.byType(TextField)), same(fieldState));
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion skips transitions and interrupts one in flight', (
    tester,
  ) async {
    Widget content(int value, bool reduced) => host(
      MotionChange(value: value, child: Text('$value')),
      reduced: reduced,
    );
    await tester.pumpWidget(content(0, false));
    await tester.pumpWidget(content(1, false));
    await tester.pump(const Duration(milliseconds: 30));
    expect(opacity(tester), lessThan(1));
    await tester.pumpWidget(content(1, true));
    expect(opacity(tester), 1);
    await tester.pumpWidget(content(2, true));
    expect(opacity(tester), 1);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('local resizing removes outgoing controls immediately', (
    tester,
  ) async {
    Widget content(bool visible, bool reduced) => host(
      MotionSize(
        child: visible
            ? SizedBox(
                height: 100,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Pick club'),
                ),
              )
            : const SizedBox.shrink(),
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(content(true, false));
    await tester.pumpWidget(content(false, false));
    expect(find.text('Pick club'), findsNothing);
    await tester.pumpAndSettle();
    await tester.pumpWidget(content(true, true));
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(find.byType(MotionSize)).height, 100);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'sheet settles instantly with reduced motion and still follows dragging',
    (tester) async {
      final key = GlobalKey<CollapsibleSheetState>();
      double collapsed = 0;
      Widget content(bool reduced) => host(
        SizedBox(
          height: 300,
          width: 300,
          child: CollapsibleSheet(
            key: key,
            peek: 100,
            builder: (context, value, wrap) {
              collapsed = value;
              return wrap(const SizedBox(height: 300, width: 300));
            },
          ),
        ),
        reduced: reduced,
      );
      await tester.pumpWidget(content(true));
      key.currentState!.close();
      await tester.pump();
      expect(collapsed, 1);
      key.currentState!.open();
      await tester.pump();
      expect(collapsed, 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CollapsibleSheet)),
      );
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(collapsed, greaterThan(0));
      expect(collapsed, lessThan(1));
      await gesture.up();
      await tester.pump();
      expect(collapsed == 0 || collapsed == 1, isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('reduced motion stops a sheet settling in flight', (
    tester,
  ) async {
    final key = GlobalKey<CollapsibleSheetState>();
    double collapsed = 0;
    Widget content(bool reduced) => host(
      CollapsibleSheet(
        key: key,
        builder: (_, value, wrap) {
          collapsed = value;
          return wrap(const SizedBox(width: 300, height: 300));
        },
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(content(false));
    key.currentState!.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(collapsed, greaterThan(0));
    expect(collapsed, lessThan(1));
    await tester.pumpWidget(content(true));
    expect(collapsed, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('loading buttons stay inert during feedback', (tester) async {
    var taps = 0;
    Widget content(bool loading, {bool reduced = false}) => host(
      PrimaryButton(label: 'SAVE', loading: loading, onPressed: () => taps++),
      reduced: reduced,
    );
    await tester.pumpWidget(content(false));
    await tester.tap(find.text('SAVE'));
    expect(taps, 1);
    await tester.pumpWidget(content(true));
    await tester.tap(find.byType(PrimaryButton));
    expect(taps, 1);
    expect(find.text('SAVE'), findsNothing);
    await tester.pumpWidget(content(true, reduced: true));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNotNull,
    );
    await tester.pumpWidget(content(false));
    await tester.tap(find.text('SAVE'));
    expect(taps, 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
