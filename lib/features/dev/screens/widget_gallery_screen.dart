import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/map/map_markers.dart';
import '../../../core/map/route_style.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../demo_routes.dart';

/// Dev flavor only (/dev/widgets): every shared widget in all its states.
class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  int _duration = 1;
  int? _bike = 1;
  bool _avoidHighways = true;
  bool _avoidUnpaved = false;
  int _filter = 0;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PasyarColors.of(context).background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              spacing: 12,
              children: [
                RoundIconButton.ground(
                  icon: LucideIcons.chevronLeft,
                  semanticLabel: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Text(
                  'WIDGETS',
                  style: PasyarTextStyles.of(context).screenTitle(32),
                ),
              ],
            ),
            const _Section('Colors', child: ColorSwatches()),
            const _Section('Typography', child: TypographySamples()),
            _Section(
              'PrimaryButton',
              child: _column([
                PrimaryButton(
                  label: 'Generate loop',
                  icon: LucideIcons.rotateCw,
                  onPressed: () {},
                ),
                PrimaryButton(label: 'LOG IN', onPressed: () {}),
                const PrimaryButton(label: 'DISABLED', onPressed: null),
                PrimaryButton(
                  label: 'LOADING',
                  onPressed: () {},
                  loading: true,
                ),
              ]),
            ),
            _Section(
              'SecondaryButton',
              child: _column([
                SecondaryButton(
                  label: 'Shuffle',
                  icon: LucideIcons.shuffle,
                  onPressed: () {},
                ),
                SecondaryButton(label: 'END RIDE', onPressed: () {}),
                const SecondaryButton(label: 'DISABLED', onPressed: null),
                Container(
                  color: PasyarColors.of(context).ink,
                  padding: const EdgeInsets.all(16),
                  child: SecondaryButton.onDark(
                    label: 'I ALREADY HAVE AN ACCOUNT',
                    onPressed: () {},
                  ),
                ),
              ]),
            ),
            _Section(
              'RoundIconButton / FloatingPill',
              child: Container(
                color: PasyarColors.of(context).mapGround,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Row(
                      spacing: 12,
                      children: [
                        RoundIconButton.floating(
                          icon: LucideIcons.chevronLeft,
                          semanticLabel: 'Back',
                          onPressed: () {},
                        ),
                        FloatingPill(
                          child: Text(
                            'HALF-DAY LOOP',
                            style: PasyarTextStyles.of(context).pillTitle,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        const Expanded(child: StartingFromPill()),
                        RoundIconButton.floating(
                          icon: LucideIcons.user,
                          semanticLabel: 'Profile',
                          onPressed: () {},
                        ),
                      ],
                    ),
                    Row(
                      spacing: 8,
                      children: [
                        RoundIconButton.ground(
                          icon: LucideIcons.search,
                          iconSize: 20,
                          semanticLabel: 'Search',
                          onPressed: () {},
                        ),
                        RoundIconButton.ground(
                          icon: LucideIcons.x,
                          semanticLabel: 'Close',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _Section(
              'ChoiceCard',
              child: _column([
                Row(
                  spacing: 10,
                  children: [
                    for (final (i, (title, sub)) in const [
                      ('QUICK', 'about 1 hr'),
                      ('HALF-DAY', 'about 4 hr'),
                      ('FULL DAY', '6 hr +'),
                    ].indexed)
                      Expanded(
                        child: ChoiceCard(
                          title: title,
                          subtitle: sub,
                          selected: _duration == i,
                          onTap: () => setState(() => _duration = i),
                        ),
                      ),
                  ],
                ),
                _grid2([
                  for (final (i, title) in const [
                    'SCOOTER',
                    'UNDERBONE',
                    'BIG BIKE',
                    'DUAL-SPORT',
                  ].indexed)
                    ChoiceCard(
                      title: title,
                      selected: _bike == i,
                      onTap: () =>
                          setState(() => _bike = _bike == i ? null : i),
                    ),
                ]),
              ]),
            ),
            _Section(
              'PillToggle',
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: PillToggle(
                      label: 'Avoid highways',
                      value: _avoidHighways,
                      onChanged: (v) => setState(() => _avoidHighways = v),
                    ),
                  ),
                  Expanded(
                    child: PillToggle(
                      label: 'Avoid unpaved',
                      value: _avoidUnpaved,
                      onChanged: (v) => setState(() => _avoidUnpaved = v),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              'FilterChip',
              child: Row(
                spacing: PasyarSpacing.chipGap,
                children: [
                  for (final (i, label) in const [
                    'Near you',
                    'Following',
                    'My clubs',
                  ].indexed)
                    PasyarFilterChip(
                      label: label,
                      selected: _filter == i,
                      onTap: () => setState(() => _filter = i),
                    ),
                ],
              ),
            ),
            const _Section('PasyarTextField', child: TextFieldStates()),
            _Section(
              'SocialButton',
              child: _column([
                SocialButton(
                  provider: SocialProvider.apple,
                  label: 'Continue with Apple',
                  onPressed: () {},
                ),
                SocialButton(
                  provider: SocialProvider.google,
                  label: 'Continue with Google',
                  onPressed: () {},
                ),
                _grid2([
                  SocialButton(
                    provider: SocialProvider.apple,
                    label: 'Apple',
                    compact: true,
                    onPressed: () {},
                  ),
                  SocialButton(
                    provider: SocialProvider.google,
                    label: 'Google',
                    compact: true,
                    onPressed: () {},
                  ),
                ]),
                _grid2([
                  SocialButton(
                    provider: SocialProvider.apple,
                    label: 'Apple',
                    compact: true,
                    loading: true,
                    onPressed: () {},
                  ),
                  const SocialButton(
                    provider: SocialProvider.google,
                    label: 'Google',
                    compact: true,
                    onPressed: null,
                  ),
                ]),
              ]),
            ),
            const _Section(
              'OrDivider',
              child: OrDivider(text: 'or log in with email'),
            ),
            _Section(
              'StepProgress',
              child: _column(const [
                StepProgress(step: 1, total: 2),
                StepProgress(step: 2, total: 2),
              ]),
            ),
            const _Section('SafetyRow', child: SafetyRows()),
            _Section(
              'StatBlock',
              child: _column([
                StatRow(
                  children: [
                    StatBlock(label: 'Distance', value: '118 km'),
                    StatBlock(label: 'Ride time', value: '3 h 50'),
                    StatBlock(
                      label: 'Curvy roads',
                      value: 'High',
                      valueColor: PasyarColors.of(context).accentDark,
                    ),
                  ],
                ),
                StatRow(
                  children: [
                    StatBlock(label: 'Distance', value: '96 km', small: true),
                    StatBlock(label: 'Ride time', value: '3 h 10', small: true),
                    StatBlock(label: 'Curvy', value: 'Medium', small: true),
                  ],
                ),
              ]),
            ),
            _Section(
              'StopCard',
              child: StopCard(
                overline: 'Main stop · 52 km in',
                name: '[Stop name] Viewpoint',
                detail: 'Photo spot · gas station nearby',
                onTap: () {},
              ),
            ),
            const _Section('Avatar', child: AvatarSamples()),
            _Section(
              'BottomSheetPanel',
              child: ColoredBox(
                color: PasyarColors.of(context).mapGround,
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: BottomSheetPanel(
                    children: [
                      Text('Sheet content'),
                      Text('16 px between groups'),
                    ],
                  ),
                ),
              ),
            ),
            _Section(
              'BottomTabs',
              child: MediaQuery.removeViewPadding(
                context: context,
                removeBottom: true,
                child: PasyarBottomTabs(
                  currentIndex: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ),
            ),
            const _Section('Route line + markers', child: DemoMaps()),
          ],
        ),
      ),
    );
  }
}

Widget _column(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 12,
  children: children,
);

Widget _grid2(List<Widget> children) => Column(
  spacing: 10,
  children: [
    for (var i = 0; i < children.length; i += 2)
      Row(
        spacing: 10,
        children: [
          Expanded(child: children[i]),
          Expanded(
            child: i + 1 < children.length ? children[i + 1] : const SizedBox(),
          ),
        ],
      ),
  ],
);

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            title.toUpperCase(),
            style: PasyarTextStyles.of(context).overline,
          ),
          child,
        ],
      ),
    );
  }
}

/// "Starting from / Current location" pill from the Home mockup.
class StartingFromPill extends StatelessWidget {
  const StartingFromPill({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingPill(
      child: Row(
        spacing: 10,
        children: [
          Icon(
            LucideIcons.locate,
            size: 18,
            color: PasyarColors.of(context).rider,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Starting from',
                style: PasyarTextStyles.of(
                  context,
                ).label.copyWith(fontSize: 12, height: 1.15),
              ),
              Text(
                'Current location',
                style: PasyarTextStyles.of(
                  context,
                ).bodyStrong.copyWith(height: 1.15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({super.key});

  static Map<String, Color> colors(BuildContext context) => {
    'ink': PasyarColors.of(context).ink,
    'muted': PasyarColors.of(context).muted,
    'ground': PasyarColors.of(context).ground,
    'card': PasyarColors.of(context).card,
    'line': PasyarColors.of(context).line,
    'lineStrong': PasyarColors.of(context).lineStrong,
    'accent': PasyarColors.of(context).accent,
    'accentDark': PasyarColors.of(context).accentDark,
    'accentTint': PasyarColors.of(context).accentTint,
    'rider': PasyarColors.of(context).rider,
    'verifiedTint': PasyarColors.of(context).verifiedTint,
    'verifiedText': PasyarColors.of(context).verifiedText,
    'mapGround': PasyarColors.of(context).mapGround,
    'riddenRoute': PasyarColors.of(context).riddenRoute,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: name, value: color) in colors(context).entries)
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PasyarColors.of(context).line),
                  ),
                ),
                Text(
                  name,
                  style: PasyarTextStyles.of(
                    context,
                  ).label.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TypographySamples extends StatelessWidget {
  const TypographySamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Container(
          width: double.infinity,
          color: PasyarColors.of(context).ink,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASYAR',
                style: PasyarTextStyles.of(
                  context,
                ).wordmark.copyWith(color: PasyarColors.of(context).card),
              ),
              Text(
                'Walang plano? Pasyar na.',
                style: PasyarTextStyles.of(context).tagline,
              ),
            ],
          ),
        ),
        Text(
          'WHERE TO TODAY?',
          style: PasyarTextStyles.of(context).screenTitle(30),
        ),
        Text(
          'WELCOME BACK',
          style: PasyarTextStyles.of(context).screenTitle(36),
        ),
        Text('400 m', style: PasyarTextStyles.of(context).navDistance),
        Text('118 km', style: PasyarTextStyles.of(context).statValue),
        Text(
          'Generate loop',
          style: PasyarTextStyles.of(context).buttonPrimary,
        ),
        Text('Shuffle', style: PasyarTextStyles.of(context).buttonSecondary),
        Text('HALF-DAY', style: PasyarTextStyles.of(context).choiceTitle),
        Text('HALF-DAY LOOP', style: PasyarTextStyles.of(context).pillTitle),
        Text(
          '[Stop name] Viewpoint',
          style: PasyarTextStyles.of(context).bodyLarge,
        ),
        Text(
          'Sunday loop with the club. Smooth roads after the bridge.',
          style: PasyarTextStyles.of(context).body,
        ),
        Text('Avoid highways', style: PasyarTextStyles.of(context).bodySmall),
        Text(
          '2 h ago · at [Stop name] Falls',
          style: PasyarTextStyles.of(context).label,
        ),
        Text('Rider name', style: PasyarTextStyles.of(context).fieldLabel),
        Text(
          'MAIN STOP · 52 KM IN',
          style: PasyarTextStyles.of(context).overline,
        ),
        Row(
          spacing: 16,
          children: [
            Text(
              'Ride',
              style: PasyarTextStyles.of(
                context,
              ).tabLabelActive.copyWith(color: PasyarColors.of(context).accent),
            ),
            Text(
              'Feed',
              style: PasyarTextStyles.of(
                context,
              ).tabLabel.copyWith(color: PasyarColors.of(context).muted),
            ),
          ],
        ),
      ],
    );
  }
}

class TextFieldStates extends StatelessWidget {
  const TextFieldStates({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const PasyarTextField(label: 'Email', hint: 'you@email.com'),
        PasyarTextField(
          label: 'Rider name',
          controller: TextEditingController(text: 'Juan'),
        ),
        PasyarTextField(
          label: 'Password',
          password: true,
          controller: TextEditingController(text: 'password123'),
        ),
        const PasyarTextField(
          label: 'Home area',
          hint: 'e.g. Cordon, Isabela',
          helper: 'Town only. Helps show loops near you.',
        ),
        PasyarTextField(
          label: 'Password',
          password: true,
          controller: TextEditingController(text: 'short'),
          error: 'Use at least 8 characters.',
        ),
        PasyarTextField(
          label: 'Caption',
          enabled: false,
          controller: TextEditingController(text: 'Locked while moving'),
          helper: 'Typing locks while moving.',
        ),
      ],
    );
  }
}

class SafetyRows extends StatelessWidget {
  const SafetyRows({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        SafetyRow(
          icon: LucideIcons.shield,
          lead: 'Your start stays private.',
          text: ' Shared routes hide the first and last 800 m.',
        ),
        SafetyRow(
          icon: LucideIcons.smartphone,
          lead: 'Mount your phone',
          text: ' before you ride.',
        ),
        SafetyRow(
          icon: LucideIcons.lock,
          lead: 'Typing locks while moving.',
          text: ' Post when you stop.',
        ),
      ],
    );
  }
}

class AvatarSamples extends StatelessWidget {
  const AvatarSamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Avatar(
          name: 'Rider Name',
          color: PasyarColors.of(context).verifiedText,
        ),
        Avatar(name: 'Iloilo Riders', color: PasyarColors.of(context).ink),
        Avatar(name: 'Ana Lim', color: PasyarColors.of(context).muted),
        Avatar(name: 'Me', size: 40, color: PasyarColors.of(context).ink),
        Avatar(
          name: 'Juan Mercado',
          size: 32,
          color: PasyarColors.of(context).accentDark,
        ),
        Avatar(name: 'Juan Dela Cruz'),
      ],
    );
  }
}

/// Preview, riding and create-loop styles on maps with no tiles.
class DemoMaps extends StatelessWidget {
  const DemoMaps({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _DemoMap(
          polylines: routePolylines(route: DemoRoutes.loop),
          markers: [
            PasyarMarkers.mainStop(DemoRoutes.mainStop),
            PasyarMarkers.rider(DemoRoutes.start, halo: false),
          ],
        ),
        _DemoMap(
          polylines: routePolylines(
            ridden: DemoRoutes.ridden,
            route: DemoRoutes.remaining,
          ),
          markers: [
            PasyarMarkers.mainStop(DemoRoutes.mainStop, radius: 14),
            PasyarMarkers.riderArrow(DemoRoutes.rider, heading: 80),
          ],
        ),
        _DemoMap(
          polylines: routePolylines(
            route: DemoRoutes.created,
            closing: DemoRoutes.closing,
          ),
          markers: [
            PasyarMarkers.loopPoint(DemoRoutes.point1, 1),
            PasyarMarkers.loopPoint(DemoRoutes.point2, 2),
            PasyarMarkers.mainStop(DemoRoutes.mainStop, radius: 15),
            PasyarMarkers.loopStart(DemoRoutes.start),
          ],
        ),
      ],
    );
  }
}

class _DemoMap extends StatelessWidget {
  const _DemoMap({required this.polylines, required this.markers});

  final List<Polyline> polylines;
  final List<Marker> markers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PasyarRadius.panel),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: DemoRoutes.loop,
              padding: const EdgeInsets.all(28),
            ),
            backgroundColor: PasyarColors.of(context).mapGround,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
