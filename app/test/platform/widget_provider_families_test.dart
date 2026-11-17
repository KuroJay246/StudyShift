import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Android widget picker offers each approved schedule family', () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final providers = manifest
        .findAllElements('receiver')
        .where((receiver) => receiver
            .findElements('meta-data')
            .any((meta) => meta.getAttribute('android:name') == 'android.appwidget.provider'))
        .map((receiver) => <String, String>{
              'class': receiver.getAttribute('android:name')!,
              'info': receiver
                  .findElements('meta-data')
                  .singleWhere((meta) =>
                      meta.getAttribute('android:name') ==
                      'android.appwidget.provider')
                  .getAttribute('android:resource')!,
            })
        .toList();

    expect(providers.map((provider) => provider['class']), containsAll([
      '.ScheduleWidgetProvider',
      '.TodayWidgetProvider',
      '.WeekWidgetProvider',
      '.NextClassWidgetProvider',
      '.DeadlineWidgetProvider',
    ]));

    final familyInfo = <String, ({String file, int width, int height})>{
      '.ScheduleWidgetProvider': (file: 'schedule_widget_info.xml', width: 2, height: 2),
      '.TodayWidgetProvider': (file: 'today_widget_info.xml', width: 4, height: 2),
      '.WeekWidgetProvider': (file: 'week_widget_info.xml', width: 4, height: 1),
      '.NextClassWidgetProvider': (file: 'next_class_widget_info.xml', width: 2, height: 2),
      '.DeadlineWidgetProvider': (file: 'deadline_widget_info.xml', width: 2, height: 2),
    };
    for (final provider in providers) {
      final name = provider['class']!;
      final expected = familyInfo[name]!;
      expect(provider['info'], '@xml/${expected.file.replaceAll('_widget_info.xml', '_widget_info')}');
      final info = XmlDocument.parse(
        File('android/app/src/main/res/xml/${expected.file}').readAsStringSync(),
      ).rootElement;
      expect(info.getAttribute('android:targetCellWidth'), '${expected.width}');
      expect(info.getAttribute('android:targetCellHeight'), '${expected.height}');
      final preview = info.getAttribute('android:previewImage')!;
      expect(preview, startsWith('@drawable/'));
      expect(
        File('android/app/src/main/res/drawable-nodpi/${preview.substring('@drawable/'.length)}.xml').existsSync(),
        isTrue,
        reason: 'Missing $preview for ${expected.file}',
      );
    }

    for (final infoPath in [
      'android/app/src/main/res/xml/schedule_widget_info.xml',
      'android/app/src/main/res/xml/today_widget_info.xml',
      'android/app/src/main/res/xml/week_widget_info.xml',
      'android/app/src/main/res/xml/next_class_widget_info.xml',
      'android/app/src/main/res/xml/deadline_widget_info.xml',
    ]) {
      expect(File(infoPath).existsSync(), isTrue, reason: infoPath);
      final provider = XmlDocument.parse(File(infoPath).readAsStringSync()).rootElement;
      expect(provider.getAttribute('android:previewLayout'), isNotNull);
      expect(provider.getAttribute('android:previewImage'), isNotNull);
      expect(provider.getAttribute('android:configure'), contains('ScheduleWidgetConfigureActivity'));
      expect(provider.getAttribute('android:resizeMode'), contains('horizontal'));
    }

    expect(File('android/app/src/main/res/layout/today_widget_preview.xml').existsSync(), isTrue);
    expect(File('android/app/src/main/res/layout/week_widget_preview.xml').existsSync(), isTrue);
    expect(File('android/app/src/main/res/layout/next_class_widget_preview.xml').existsSync(), isTrue);
    expect(File('android/app/src/main/res/layout/deadline_widget_preview.xml').existsSync(), isTrue);
  });
}
