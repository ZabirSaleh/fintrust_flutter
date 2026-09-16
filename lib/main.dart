import 'package:flutter/material.dart';

import 'features/fintrust_screens.dart';
import 'services/fintrust_backend.dart';
import 'services/fintrust_controller.dart';
import 'widgets/fintrust_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await FintrustBackendFactory.create();
  runApp(FintrustApp(backend: backend));
}

class FintrustApp extends StatefulWidget {
  const FintrustApp({required this.backend, super.key});

  final FintrustBackend backend;

  @override
  State<FintrustApp> createState() => _FintrustAppState();
}

class _FintrustAppState extends State<FintrustApp> {
  late final FintrustController _controller;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _controller = FintrustController(widget.backend);
    _isDarkMode = _controller.isDarkMode;
    _controller.addListener(_handleThemeChange);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleThemeChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleThemeChange() {
    if (_isDarkMode == _controller.isDarkMode) {
      return;
    }

    setState(() {
      _isDarkMode = _controller.isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FintrustScope(
      controller: _controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FINTRUST',
        theme: buildFintrustTheme(dark: _isDarkMode),
        home: const FintrustRoot(),
      ),
    );
  }
}

class FintrustRoot extends StatelessWidget {
  const FintrustRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);

    if (controller.isInitializing) {
      return const _BootScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: controller.isSignedIn
          ? const DashboardShell(key: ValueKey('dashboard'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 18),
              Text(
                'Restoring FINTRUST session',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
