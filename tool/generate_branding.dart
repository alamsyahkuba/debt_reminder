import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final sourceFile = File('assets/branding/logo.jpg');
  final source = img.decodeImage(sourceFile.readAsBytesSync());
  if (source == null) {
    throw StateError('Logo sumber tidak dapat dibaca.');
  }

  File('assets/branding/app_icon.png')
      .writeAsBytesSync(_renderIcon(source, logoSize: 800));
  File('assets/branding/app_icon_foreground.png')
      .writeAsBytesSync(_renderIcon(source, logoSize: 640));
  File('assets/branding/splash_logo.png')
      .writeAsBytesSync(_renderIcon(source, canvasSize: 640, logoSize: 500));
}

List<int> _renderIcon(
  img.Image source, {
  int canvasSize = 1024,
  required int logoSize,
}) {
  final icon = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(icon, color: img.ColorRgb8(255, 255, 255));

  final logo = img.copyResize(
    source,
    width: logoSize,
    height: logoSize,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(icon, logo, center: true);
  return img.encodePng(icon);
}
