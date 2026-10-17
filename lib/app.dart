import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme/pasyar_theme.dart';
import 'features/auth/providers/auth_provider.dart';

/// Expects an [AuthProvider] above it (see main.dart).
class PasyarApp extends StatefulWidget {
  const PasyarApp({super.key});

  @override
  State<PasyarApp> createState() => _PasyarAppState();
}

class _PasyarAppState extends State<PasyarApp> {
  late final GoRouter _router = createRouter(
    auth: context.read<AuthProvider>(),
  );

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
