import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/map/map_markers.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';
import 'package:pasyarph/features/dev/screens/widget_gallery_screen.dart';

void main() {
  group('Golden', () {
    goldenTest(
      'Map markers',
      fileName: 'map_markers',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'markers',
            child: Container(
              color: PasyarColors.mapGround,
              padding: const EdgeInsets.all(12),
              child: const Row(
                spacing: 16,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RiderDot(),
                  RiderDot(halo: false),
                  RiderArrow(heading: 80),
                  MainStopMarker(),
                  MainStopMarker(radius: 14),
                  LoopPointMarker.start(),
                  LoopPointMarker(label: '1'),
                  LoopPointMarker(label: '12'),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'Route lines on a map',
      fileName: 'route_lines',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'preview, riding, create',
            child: const SizedBox(width: 390, child: DemoMaps()),
          ),
        ],
      ),
    );
  });
}
