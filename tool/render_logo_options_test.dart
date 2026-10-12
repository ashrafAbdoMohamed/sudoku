// Renders the alternative app icon designs side by side with the current
// one, to store/logo_options.png, for choosing a design.
// Run: flutter test tool/render_logo_options_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/game/app_logo.dart';
import 'package:sudoku/game/app_logo_options.dart';
import 'package:sudoku/game/ui_kit.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  testWidgets('render logo options', (tester) async {
    await tester.runAsync(() async {
      await _loadFont(kTitleFont, ['assets/fonts/LuckiestGuy-Regular.ttf']);
      await _loadFont(kBodyFont, ['assets/fonts/Fredoka-Bold.ttf']);
      await _loadFont('MaterialIcons', ['${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/Caskroom/flutter/latest/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    });
    const tile = 420.0;
    Widget icon(Widget art, String label) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(tile * 0.22), child: SizedBox.square(dimension: tile, child: art)),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontFamily: kTitleFont, fontSize: 40, color: Color(0xFF3D2B7A))),
          ],
        );
    final key = GlobalKey();
    const size = Size(4 * tile + 5 * 50, tile + 160);
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFFFFF8EA),
            width: size.width,
            height: size.height,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                icon(const AppLogo(size: tile), 'CURRENT'),
                icon(const AppLogoOption(LogoOption.board, size: tile), 'A: BOARD'),
                icon(const AppLogoOption(LogoOption.versus, size: tile), 'B: VERSUS'),
                icon(const AppLogoOption(LogoOption.bigNine, size: tile), 'C: BIG 9'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('store/logo_options.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
