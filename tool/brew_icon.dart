// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

/// Prepares the launcher-icon inputs consumed by `flutter_launcher_icons`.
///
/// - `assets/generated/app_icon.png` — full-bleed 1024×1024 legacy icon
///   (used for the round & square shapes on API < 26).
/// - `assets/generated/app_icon_foreground.png` — 1024×1024 with a large
///   transparent margin so the joker sits comfortably inside the
///   66 %-safe zone of Android's adaptive-icon canvas.
/// - `assets/generated/app_icon_background.png` — solid crimson square
///   matching the halo behind the joker on icon2.png.
///
/// The user's requirement: "иконка должна быть полностью видна и
/// адаптивна". Adaptive icons crop the outer ~15 % to fit round / squircle
/// masks; a foreground that fills the raw square would clip the joker's
/// hat and cards on Pixel / Samsung launchers. We instead paint the
/// joker into the central 66 % safe zone and let a solid background
/// fill the rest — that keeps the joker whole in every mask shape.
Future<void> main() async {
  const String source = 'assets/icon2.png';
  const String outDir = 'assets/generated';

  final File src = File(source);
  if (!src.existsSync()) {
    stderr.writeln('missing $source');
    exit(1);
  }

  final img.Image? raw = img.decodePng(src.readAsBytesSync());
  if (raw == null) {
    stderr.writeln('cannot decode $source');
    exit(1);
  }

  Directory(outDir).createSync(recursive: true);

  // 1024 canvas — flutter_launcher_icons downscales to every density.
  const int canvas = 1024;

  // ── Full-bleed legacy icon ──
  final img.Image legacy = img.copyResize(
    raw,
    width: canvas,
    height: canvas,
    interpolation: img.Interpolation.cubic,
  );
  File('$outDir/app_icon.png')
      .writeAsBytesSync(img.encodePng(legacy, level: 6));

  // ── Solid background ──
  // Deep crimson matching the halo behind the joker. Feels branded and
  // hides the seam between foreground margin and mask.
  final img.Image background = img.Image(
    width: canvas,
    height: canvas,
    numChannels: 4,
  );
  img.fill(background, color: img.ColorRgb8(0x8B, 0x0F, 0x24));
  File('$outDir/app_icon_background.png')
      .writeAsBytesSync(img.encodePng(background, level: 6));

  // ── Adaptive foreground ──
  // `flutter_launcher_icons` already wraps the foreground in a 16 %
  // <inset> in mipmap-anydpi-v26/ic_launcher.xml, which pushes content
  // into Android's adaptive-icon safe zone (66 dp of a 108 dp canvas).
  // We therefore ship the foreground FULL-BLEED — layering another
  // safe-zone margin here would double-inset the joker and shrink it
  // to ~30 % of the mask. If the plugin's default inset ever changes,
  // adjust the XML instead of this file.
  final img.Image foreground = img.copyResize(
    raw,
    width: canvas,
    height: canvas,
    interpolation: img.Interpolation.cubic,
  );
  File('$outDir/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground, level: 6));

  // ── Source copy (kept for reference / re-runs) ──
  File('$outDir/app_icon_source.png')
      .writeAsBytesSync(img.encodePng(legacy, level: 6));

  print('wrote $outDir/app_icon.png (${legacy.width}×${legacy.height})');
  print('wrote $outDir/app_icon_background.png (solid crimson)');
  print('wrote $outDir/app_icon_foreground.png (full-bleed, plugin insets)');
}
