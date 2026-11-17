import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('expanded widget content starts at the top of its cell', () {
    final file = File('android/app/src/main/res/layout/schedule_widget.xml');
    final document = XmlDocument.parse(file.readAsStringSync());
    final root = document.rootElement;

    expect(root.getAttribute('android:gravity'), 'top');
    final detail = document
        .findAllElements('TextView')
        .singleWhere(
          (element) =>
              element.getAttribute('android:id') == '@+id/widget_detail',
        );
    expect(detail.getAttribute('android:maxLines'), '2');
    final secondEntry = document
        .findAllElements('TextView')
        .where(
          (element) => (element.getAttribute('android:id') ?? '').startsWith(
            '@+id/widget_second_',
          ),
        );
    expect(secondEntry.length, 3);
    expect(
      secondEntry.map((element) => element.getAttribute('android:visibility')),
      everyElement('gone'),
    );
  });

  test('widget card fills its transparent launcher slot', () {
    final file = File('android/app/src/main/res/layout/schedule_widget.xml');
    final document = XmlDocument.parse(file.readAsStringSync());
    final root = document.rootElement;
    final card = document
        .findAllElements('LinearLayout')
        .singleWhere(
          (element) =>
              element.getAttribute('android:id') == '@+id/widget_card',
        );

    expect(root.getAttribute('android:background'), '@android:color/transparent');
    expect(card.getAttribute('android:layout_height'), 'match_parent');
    expect(card.getAttribute('android:gravity'), 'top');
    expect(card.getAttribute('android:background'), '@drawable/studyshift_widget_background');
  });

  test('widget setup exposes a transparent background appearance', () {
    final file = File(
      'android/app/src/main/res/values/schedule_widget_strings.xml',
    );
    final document = XmlDocument.parse(file.readAsStringSync());
    final options = document
        .findAllElements('string-array')
        .singleWhere(
          (element) =>
              element.getAttribute('name') ==
              'schedule_widget_appearance_options',
        )
        .findElements('item')
        .map((item) => item.innerText)
        .toList();

    expect(options, ['System', 'Light', 'Dark', 'Glass', 'Transparent']);
  });

  test('widget picker presents a schedule preview instead of the app icon', () {
    final providerFile = File(
      'android/app/src/main/res/xml/schedule_widget_info.xml',
    );
    final provider = XmlDocument.parse(providerFile.readAsStringSync())
        .rootElement;

    expect(
      provider.getAttribute('android:previewLayout'),
      '@layout/schedule_widget_preview',
    );
    expect(
      provider.getAttribute('android:previewImage'),
      '@drawable/studyshift_widget_preview',
    );

    final previewFile = File(
      'android/app/src/main/res/layout/schedule_widget_preview.xml',
    );
    final preview = XmlDocument.parse(previewFile.readAsStringSync());
    expect(
      preview.rootElement.getAttribute('android:background'),
      '@android:color/transparent',
    );
    final previewCard = preview.findAllElements('LinearLayout').single;
    expect(previewCard.getAttribute('android:layout_height'), 'match_parent');
    expect(previewCard.getAttribute('android:layout_gravity'), 'top');
    expect(previewCard.getAttribute('android:background'), '@drawable/studyshift_widget_background');
    final labels = preview
        .findAllElements('TextView')
        .map((element) => element.getAttribute('android:text'))
        .whereType<String>()
        .toList();

    expect(labels, contains('NEXT UP'));
    expect(labels, contains('Your next event'));
    expect(labels, contains('Add a shift, class or plan to see it here.'));
    final previewTitle = preview
        .findAllElements('TextView')
        .singleWhere(
          (element) =>
              element.getAttribute('android:text') == 'Your schedule',
        );
    expect(previewTitle.getAttribute('android:maxLines'), '2');
    expect(previewTitle.getAttribute('android:textSize'), '19sp');
    expect(labels, isNot(contains('Sat, Nov 14')));
    expect(labels, isNot(contains('IN 2H 30M')));
    expect(labels, isNot(contains('Work shift')));
    expect(labels, isNot(contains('1:00 PM – 4:00 PM')));

    final todayPreviewFile = File(
      'android/app/src/main/res/layout/today_widget_preview.xml',
    );
    final todayPreview = XmlDocument.parse(todayPreviewFile.readAsStringSync());
    final todayLabels = todayPreview
        .findAllElements('TextView')
        .map((element) => element.getAttribute('android:text'))
        .whereType<String>()
        .toList();
    expect(todayLabels, contains('TODAY'));
    expect(todayLabels, contains('Your schedule'));
    expect(todayLabels, contains('Work, study and plans at a glance'));
    expect(todayLabels, isNot(contains('Class session')));

    const remainingPreviews = <String, List<String>>{
      'week_widget_preview.xml': ['THIS WEEK', 'Your week at a glance'],
      'next_class_widget_preview.xml': [
        'NEXT CLASS',
        'Your next class',
        'Add a class to see it here.',
      ],
      'deadline_widget_preview.xml': [
        'NEXT DEADLINE',
        'Your assignment or exam',
        'Add a deadline to see it here.',
      ],
    };
    for (final entry in remainingPreviews.entries) {
      final file = File('android/app/src/main/res/layout/${entry.key}');
      final layout = XmlDocument.parse(file.readAsStringSync());
      final copy = layout
          .findAllElements('TextView')
          .map((element) => element.getAttribute('android:text'))
          .whereType<String>()
          .toList();
      for (final label in entry.value) {
        expect(copy, contains(label), reason: entry.key);
      }
      expect(
        copy.join(' '),
        isNot(contains(RegExp(r'Sat, Nov 14|1:00 PM|5:30 PM|Operations Management|Operations assignment|6 EVENTS'))),
        reason: entry.key,
      );
    }
    expect(todayLabels, isNot(contains('Operations Management')));
  });
}
