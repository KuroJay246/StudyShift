import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  const variants = {
    'Blue': 'blue',
    'Teal': 'teal',
    'Violet': 'violet',
    'Amber': 'amber',
    'Red': 'red',
  };

  for (final directory in ['values-v31', 'values-night-v31']) {
    test('$directory system splash uses the complete themed app icon', () {
      final file = File('android/app/src/main/res/$directory/styles.xml');
      final document = XmlDocument.parse(file.readAsStringSync());
      final styles = {
        for (final style in document.findAllElements('style'))
          style.getAttribute('name'): style,
      };

      for (final entry in variants.entries) {
        final mode = directory == 'values-v31' ? 'Light' : 'Dark';
        final style = styles['LaunchTheme${entry.key}$mode'];
        expect(style, isNotNull, reason: 'Missing ${entry.key} $mode theme');
        final icon = style!
            .findElements('item')
            .firstWhere(
              (item) =>
                  item.getAttribute('name') ==
                  'android:windowSplashScreenAnimatedIcon',
            )
            .innerText;
        expect(icon, '@drawable/studyshift_splash_icon_${entry.value}');
      }
    });
  }

  test('every system splash uses its matching complete themed app icon', () {
    for (final directory in ['values-v31', 'values-night-v31']) {
      final document = XmlDocument.parse(
        File('android/app/src/main/res/$directory/styles.xml')
            .readAsStringSync(),
      );
      final launchStyles = document
          .findAllElements('style')
          .where((style) => style.getAttribute('name')?.startsWith('LaunchTheme') ?? false);
      for (final style in launchStyles) {
        final name = style.getAttribute('name')!;
        final theme = variants.keys.firstWhere(
          (variant) => name.startsWith('LaunchTheme$variant'),
          orElse: () => 'Blue',
        );
        final value = variants[theme]!;
        final icon = style
            .findElements('item')
            .where((item) => item.getAttribute('name') == 'android:windowSplashScreenAnimatedIcon')
            .map((item) => item.innerText)
            .firstOrNull;
        expect(
          icon,
          '@drawable/studyshift_splash_icon_$value',
          reason: name,
        );
      }
    }
  });

  for (final entry in variants.entries) {
    test('${entry.key} splash icon combines its background and S artwork', () {
      final file = File(
        'android/app/src/main/res/drawable/studyshift_splash_icon_${entry.value}.xml',
      );
      expect(file.existsSync(), isTrue);
      final document = XmlDocument.parse(file.readAsStringSync());
      expect(document.rootElement.name.local, 'layer-list');
      final layers = document.rootElement.findElements('item').toList();
      expect(layers, hasLength(2));
      expect(
        layers[0].getAttribute('android:drawable'),
        '@drawable/studyshift_launcher_background${entry.value == 'blue' ? '' : '_${entry.value}'}',
      );
      expect(
        layers[1].getAttribute('android:drawable'),
        '@drawable/studyshift_launcher_foreground_${entry.value}',
      );
    });
  }

  for (final entry in variants.entries) {
    test('${entry.key} launcher uses the approved raster S artwork', () {
      final assetName = 'studyshift_symbol_${entry.value}';
      final file = File(
        'android/app/src/main/res/drawable-nodpi/studyshift_launcher_foreground_${entry.value}.xml',
      );
      expect(file.existsSync(), isTrue);
      final document = XmlDocument.parse(file.readAsStringSync());
      expect(document.rootElement.name.local, 'layer-list');
      final iconLayer = document.rootElement.findElements('item').single;
      expect(iconLayer.getAttribute('android:width'), '78dp');
      expect(iconLayer.getAttribute('android:height'), '78dp');
      expect(iconLayer.getAttribute('android:gravity'), 'center');
      expect(
        iconLayer.findElements('bitmap').single.getAttribute('android:src'),
        '@drawable/$assetName',
      );

      final flutterArtwork = File(
        'assets/branding/${assetName.replaceAll('_', '-')}.png',
      );
      final androidArtwork = File(
        'android/app/src/main/res/drawable-nodpi/$assetName.png',
      );
      expect(androidArtwork.existsSync(), isTrue);
      expect(flutterArtwork.readAsBytesSync().length, greaterThan(24));
      final imageBytes = flutterArtwork.readAsBytesSync();
      expect(imageBytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      expect(_readPngDimension(imageBytes, 16), 1024);
      expect(_readPngDimension(imageBytes, 20), 1024);
      expect(
        androidArtwork.readAsBytesSync(),
        flutterArtwork.readAsBytesSync(),
      );

      final launcherName = entry.value == 'blue'
          ? 'ic_launcher'
          : 'ic_launcher_${entry.value}';
      final launcher = XmlDocument.parse(
        File('android/app/src/main/res/mipmap-anydpi-v26/$launcherName.xml')
            .readAsStringSync(),
      );
      expect(
        launcher.rootElement
            .findElements('foreground')
            .single
            .getAttribute('android:drawable'),
        '@drawable/studyshift_launcher_foreground_${entry.value}',
      );

      final splashIcon = XmlDocument.parse(
        File(
          'android/app/src/main/res/drawable/studyshift_splash_icon_${entry.value}.xml',
        ).readAsStringSync(),
      );
      expect(splashIcon.rootElement.name.local, 'layer-list');
      expect(splashIcon.rootElement.findElements('item'), hasLength(2));
    });
  }
}

int _readPngDimension(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
