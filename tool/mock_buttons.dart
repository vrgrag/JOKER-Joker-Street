// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Renders quick previews of the four gray-portal screens with our
/// [NeonPillButton] mocked on top so we can visually verify:
///   • buttons are horizontally centred
///   • bottom offset does not clip artwork
///   • landscape layouts do not get pushed off-centre by side notches
///     (we deliberately render WITHOUT any "cutout" band)
///
/// Not shipped with the app.
void main() {
  const List<(String, String, List<String>, bool)> scenes = <(String, String, List<String>, bool)>[
    (
      'assets/Vertical_Notification_GREY.webp',
      'notification_portrait',
      <String>['Accept', 'Skip'],
      false,
    ),
    (
      'assets/Horizontal_Notification_GREY.webp',
      'notification_landscape',
      <String>['Accept', 'Skip'],
      true,
    ),
    (
      'assets/Vertical_NoWiFi_GREY.webp',
      'nowifi_portrait',
      <String>['Try Again'],
      false,
    ),
    (
      'assets/Horizontal_NoWiFi_GREY.webp',
      'nowifi_landscape',
      <String>['Try Again'],
      true,
    ),
  ];

  Directory('build/preview').createSync(recursive: true);

  for (final (String path, String label, List<String> buttons, bool land)
      in scenes) {
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
    final img.Image scene = img.copyResize(
      decoded,
      width: land ? 900 : 480,
      interpolation: img.Interpolation.average,
    );
    _drawButtons(scene, buttons, land);
    final String out = 'build/preview/${label}_mock.png';
    File(out).writeAsBytesSync(img.encodePng(scene));
    print('wrote $out');
  }
}

void _drawButtons(img.Image canvas, List<String> labels, bool landscape) {
  final int w = canvas.width;
  final int h = canvas.height;

  // Match runtime widget widths from NoticeInviteScene / NoLinkScene.
  // Landscape: primary ~34 %, secondary ~24 %, Row centred.
  // Portrait: primary ~72 % / 62 %, secondary ~48 %, stacked.

  final List<(int, String)> pillWidths = <(int, String)>[];
  for (int i = 0; i < labels.length; i++) {
    final bool primary = i == 0;
    final double factor = landscape
        ? (primary ? 0.34 : 0.24)
        : (labels.length == 1 ? 0.62 : (primary ? 0.72 : 0.48));
    pillWidths.add(((w * factor).round(), labels[i]));
  }

  final int pillH = landscape ? 52 : 66;
  final int gap = 14;

  if (landscape) {
    // Row centred.
    final int totalW =
        pillWidths.fold<int>(0, (int a, (int, String) e) => a + e.$1) +
            gap * (pillWidths.length - 1);
    int cursorX = (w - totalW) ~/ 2;
    final int baseY = h - (h * 0.06).round() - pillH;
    for (final (int pw, String lbl) in pillWidths) {
      _pill(canvas, cursorX, baseY, pw, pillH, lbl, isPrimary: lbl != 'Skip');
      cursorX += pw + gap;
    }
  } else {
    // Column stacked.
    int totalH = pillWidths.length * pillH + gap * (pillWidths.length - 1);
    int cursorY = h - (h * (labels.length == 1 ? 0.08 : 0.06)).round() - totalH;
    for (final (int pw, String lbl) in pillWidths) {
      final int x = (w - pw) ~/ 2;
      _pill(canvas, x, cursorY, pw, pillH, lbl, isPrimary: lbl != 'Skip');
      cursorY += pillH + gap;
    }
  }
}

void _pill(
  img.Image canvas,
  int x,
  int y,
  int w,
  int h,
  String label, {
  required bool isPrimary,
}) {
  // Solid pill body with a warm gradient approximation. Border radius
  // ~ h/2. Draws roughly what NeonPillButton renders on-device.
  final int radius = h ~/ 2;
  final img.Color body = isPrimary
      ? img.ColorRgb8(0xFF, 0xC9, 0x4A) // festival gold
      : img.ColorRgb8(0x2A, 0x0E, 0x4A); // deep purple
  final img.Color border = img.ColorRgb8(0xFF, 0xC9, 0x4A);
  final img.Color labelColor = isPrimary
      ? img.ColorRgb8(0x1B, 0x0B, 0x33)
      : img.ColorRgb8(0xFF, 0xF6, 0xE4);

  _roundedRect(canvas, x, y, w, h, radius, body);
  _roundedRectOutline(canvas, x, y, w, h, radius, border, thickness: 3);

  // Approximate text width to centre the label.
  final img.BitmapFont font = img.arial24;
  final int approxTextW = label.length * (font.size ~/ 2 + 5);
  final int textX = x + (w - approxTextW) ~/ 2;
  final int textY = y + (h - font.size) ~/ 2;
  img.drawString(
    canvas,
    label,
    font: font,
    x: textX,
    y: textY,
    color: labelColor,
  );
}

void _roundedRect(
  img.Image canvas,
  int x,
  int y,
  int w,
  int h,
  int r,
  img.Color color,
) {
  for (int yy = 0; yy < h; yy++) {
    for (int xx = 0; xx < w; xx++) {
      // Corner mask.
      final int dx = xx < r
          ? r - xx
          : (xx >= w - r ? xx - (w - r - 1) : 0);
      final int dy = yy < r
          ? r - yy
          : (yy >= h - r ? yy - (h - r - 1) : 0);
      if (dx * dx + dy * dy > r * r) continue;
      canvas.setPixel(x + xx, y + yy, color);
    }
  }
}

void _roundedRectOutline(
  img.Image canvas,
  int x,
  int y,
  int w,
  int h,
  int r,
  img.Color color, {
  int thickness = 2,
}) {
  for (int t = 0; t < thickness; t++) {
    final int rt = r - t;
    for (int i = 0; i <= 360; i++) {
      final double rad = i * math.pi / 180;
      // Four corner arcs.
      final int cx1 = x + r, cy1 = y + r;
      final int cx2 = x + w - r - 1, cy2 = y + r;
      final int cx3 = x + r, cy3 = y + h - r - 1;
      final int cx4 = x + w - r - 1, cy4 = y + h - r - 1;
      final int ox = (rt * math.cos(rad)).round();
      final int oy = (rt * math.sin(rad)).round();
      _plot(canvas, cx1 - ox.abs(), cy1 - oy.abs(), color);
      _plot(canvas, cx2 + ox.abs(), cy2 - oy.abs(), color);
      _plot(canvas, cx3 - ox.abs(), cy3 + oy.abs(), color);
      _plot(canvas, cx4 + ox.abs(), cy4 + oy.abs(), color);
    }
    // Straight edges.
    for (int i = r; i < w - r; i++) {
      _plot(canvas, x + i, y + t, color);
      _plot(canvas, x + i, y + h - 1 - t, color);
    }
    for (int i = r; i < h - r; i++) {
      _plot(canvas, x + t, y + i, color);
      _plot(canvas, x + w - 1 - t, y + i, color);
    }
  }
}

void _plot(img.Image canvas, int x, int y, img.Color color) {
  if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return;
  canvas.setPixel(x, y, color);
}
