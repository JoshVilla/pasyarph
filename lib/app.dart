import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme/pasyar_theme.dart';

class PasyarApp extends StatefulWidget {
  const PasyarApp({super.key});

  @override
  State<PasyarApp> createState() => _PasyarAppState();
}

class _PasyarAppState extends State<PasyarApp> {
  final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pasyar',
      debugShowCheckedModeBanner: false,
      theme: PasyarTheme.light(),
      routerConfig: _router,
    );
  }
}
