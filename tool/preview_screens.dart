// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

/// Converts the four gray screens (portrait + landscape × notification
/// + no-wifi) into small PNG previews that Claude can render inline
/// while designing the button placements. Not shipped in the app.
void main() {
  const List<String> sources = <String>[
    'assets/Vertical_Notification_GREY.webp',
    'assets/Horizontal_Notification_GREY.webp',
    'assets/Vertical_NoWiFi_GREY.webp',
    'assets/Horizontal_NoWiFi_GREY.webp',
    'assets/Vertical_Loading.webp',
    'assets/Horizontal_Loading.webp',
  ];

  Directory('build/preview').createSync(recursive: true);

  for (final String path in sources) {
    final File file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('missing $path');
      continue;
    }
    final img.Image? decoded = img.decodeWebP(file.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('cannot decode $path');
      continue;
    }
    final img.Image scaled = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? 720 : 405,
      interpolation: img.Interpolation.average,
    );
    final String outName =
        path.split('/').last.replaceAll('.webp', '_preview.png');
    File('build/preview/$outName').writeAsBytesSync(img.encodePng(scaled));
    print('wrote build/preview/$outName');
  }
}
