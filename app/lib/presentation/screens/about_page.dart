import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/preferences_repository.dart';
import '../../platform/app_version_bridge.dart';
import '../design/studyshift_spacing.dart';
import '../widgets/shift_brand_mark.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key, this.versionBridge = const AppVersionBridge()});

  final AppVersionBridge versionBridge;

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  late final Future<InstalledAppVersion> _version = widget.versionBridge
      .readInstalledVersion();

  @override
  Widget build(BuildContext context) {
    final accentTheme =
        ref.watch(appPreferencesProvider).value?.accentTheme ??
        AccentTheme.studyShiftBlue;
    return Scaffold(
      appBar: AppBar(title: const Text('About StudyShift')),
      body: ListView(
        padding: const EdgeInsets.all(StudyShiftSpacing.pageMargin),
        children: [
          const SizedBox(height: 12),
          Center(
            child: StudyShiftBrandMark(size: 92, accentTheme: accentTheme),
          ),
          const SizedBox(height: 14),
          const Center(child: StudyShiftWordmark()),
          const SizedBox(height: 8),
          Text(
            'Work · Study · Plan · Balance',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: FutureBuilder<InstalledAppVersion>(
              future: _version,
              builder: (context, snapshot) {
                final label = switch (snapshot.connectionState) {
                  ConnectionState.waiting => 'Checking installed version…',
                  _ when snapshot.hasError => 'Version information unavailable',
                  _ => snapshot.requireData.label,
                };
                return ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('StudyShift'),
                  subtitle: Text(label),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Private by design'),
              subtitle: Text(
                'Your schedule is stored on this device and works offline. '
                'No account or cloud service is required.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Personal alpha',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
