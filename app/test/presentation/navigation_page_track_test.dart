import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/presentation/widgets/navigation_page_track.dart';

class _BuildProbe extends StatefulWidget {
  const _BuildProbe(this.onBuild, {super.key});

  final VoidCallback onBuild;

  @override
  State<_BuildProbe> createState() => _BuildProbeState();
}

class _BuildProbeState extends State<_BuildProbe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.expand();
  }
}

void main() {
  testWidgets('drag position updates transforms without rebuilding pages', (
    tester,
  ) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    var firstPageBuilds = 0;
    var secondPageBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: NavigationPageTrack(
            pagePosition: position,
            pageWidth: 400,
            selectedIndex: 0,
            pages: [
              _BuildProbe(() => firstPageBuilds++, key: const Key('today')),
              _BuildProbe(() => secondPageBuilds++, key: const Key('week')),
            ],
          ),
        ),
      ),
    );

    final initialFirstPageBuilds = firstPageBuilds;
    final initialSecondPageBuilds = secondPageBuilds;
    position.value = 0.25;
    await tester.pump();

    expect(firstPageBuilds, initialFirstPageBuilds);
    expect(secondPageBuilds, initialSecondPageBuilds);
    expect(
      tester
          .widget<Transform>(
            find.byKey(const Key('navigation-page-transform-1')),
          )
          .transform
          .getTranslation()
          .x,
      300,
    );
  });
}
