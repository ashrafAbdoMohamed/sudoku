// Renders the app icon art to PNGs in assets/branding/.
// Run: flutter test tool/render_logo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/game/app_logo.dart';
import 'package:sudoku/game/ui_kit.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

Future<void> _render(WidgetTester tester, Widget widget, String out) async {
  const size = 1024.0;
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(size, size));
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RepaintBoundary(key: key, child: widget)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render app logo', (tester) async {
    await tester.runAsync(() => _loadFont(kTitleFont, 'assets/fonts/LuckiestGuy-Regular.ttf'));
    const dir = 'assets/branding';
    await _render(tester, const AppLogo(size: 1024), '$dir/icon.png');
    await _render(tester, const AppLogo(size: 1024, layer: LogoLayer.background), '$dir/icon_background.png');
    await _render(tester, const AppLogo(size: 1024, layer: LogoLayer.foreground), '$dir/icon_foreground.png');
    await _render(tester, const AppLogo(size: 1024, layer: LogoLayer.monochrome), '$dir/icon_monochrome.png');
  });
}
