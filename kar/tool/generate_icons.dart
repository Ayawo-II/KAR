import 'dart:io';

import 'package:image/image.dart' as img;

final img.Color themeBlue = img.ColorRgb8(0x1E, 0x88, 0xE5);
final img.Color accentCyan = img.ColorRgb8(0x00, 0xBF, 0xA5);
final img.Color white = img.ColorRgb8(0xFF, 0xFF, 0xFF);

void main() {
  _generate(192);
  _generate(512);
  _generate(192, maskable: true);
  _generate(512, maskable: true);
  _generateAndroid();
}

void _generateAndroid() {
  const targets = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  targets.forEach((dir, size) {
    final icon = _build(size);
    final path = 'android/app/src/main/res/$dir/ic_launcher.png';
    File(path).writeAsBytesSync(img.encodePng(icon));
    stdout.writeln('created: $path');
  });
}

void _generate(int size, {bool maskable = false}) {
  final canvas = _build(size, maskable: maskable, showLetter: true);

  final fileName =
      'web/icons/Icon${maskable ? '-maskable' : ''}-$size.png';
  File(fileName).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('created: $fileName');
}

img.Image _build(int size, {bool maskable = false, bool showLetter = true}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);

  img.fill(canvas, color: themeBlue);

  double circleRadius = size * (maskable ? 0.38 : 0.45);
  final cx = size / 2;
  final cy = size / 2;
  img.fillCircle(
    canvas,
    x: cx.round(),
    y: cy.round(),
    radius: circleRadius.round(),
    color: white,
  );

  if (showLetter) {
    final kImage = _renderK(size);
    final kSize = (size * (maskable ? 0.42 : 0.5)).round();
    final scaledK = img.copyResize(kImage, width: kSize, height: kSize);
    img.compositeImage(
      canvas,
      scaledK,
      dstX: ((size - kSize) / 2).round(),
      dstY: ((size - kSize) / 2).round(),
    );
  }

  return canvas;
}

img.Image _renderK(int targetSize) {
  final textLayer = img.Image(width: 256, height: 256, numChannels: 4);
  img.drawString(textLayer, 'K', font: img.arial48, x: 0, y: 0, color: themeBlue);

  int minX = 256, minY = 256, maxX = 0, maxY = 0;
  for (var y = 0; y < textLayer.height; y++) {
    for (var x = 0; x < textLayer.width; x++) {
      final p = textLayer.getPixel(x, y);
      if (p.a > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  final w = maxX - minX + 1;
  final h = maxY - minY + 1;
  return img.copyCrop(textLayer, x: minX, y: minY, width: w, height: h);
}