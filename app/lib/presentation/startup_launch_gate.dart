import 'dart:async';

import 'package:flutter/material.dart';

import '../data/preferences_repository.dart';
import 'startup_splash.dart';

class StartupLaunchGate extends StatefulWidget {
  const StartupLaunchGate({
    required this.ready,
    required this.finished,
    required this.child,
    this.accentTheme = AccentTheme.studyShiftBlue,
    super.key,
  });

  final bool ready;
  final bool finished;
  final Widget child;
  final AccentTheme accentTheme;
  @override
  State<StartupLaunchGate> createState() => _StartupLaunchGateState();
}

class _StartupLaunchGateState extends State<StartupLaunchGate> {
  Timer? _minimumTimer;
  bool _minimumElapsed = false;
  bool _enteredApp = false;
  bool _timersStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timersStarted) return;
    _timersStarted = true;
    // Android keeps its native splash visible until Flutter draws the first
    // frame. Start our branded screen's minimum duration after that frame so
    // the OS splash cannot consume the whole animation while Flutter starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      _minimumTimer = Timer(
        Duration(milliseconds: reducedMotion ? 250 : 1800),
        _onMinimumElapsed,
      );
    });
  }

  @override
  void didUpdateWidget(covariant StartupLaunchGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enterWhenReady();
  }

  void _onMinimumElapsed() {
    if (!mounted) return;
    setState(() {
      _minimumElapsed = true;
      _enterWhenReady();
    });
  }

  void _enterWhenReady() {
    if (_minimumElapsed && widget.finished) _enteredApp = true;
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _enterWhenReady();
    if (_enteredApp) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(widget.child.runtimeType),
          child: widget.child,
        ),
      );
    }
    if (_minimumElapsed && !widget.finished) {
      return const StartupLoadingScreen();
    }
    return StudyShiftSplash(
      ready: widget.ready,
      accentTheme: widget.accentTheme,
    );
  }
}

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Loading your private schedule',
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 20),
          Text(
            'Still loading your schedule…',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_rounded, size: 44),
              const SizedBox(height: 16),
              Text(
                'Your schedule could not be opened',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your saved events are still on this device. Try opening them again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              if (!const bool.fromEnvironment('dart.vm.product'))
                Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );
}
