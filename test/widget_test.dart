import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/screens/splash_screen.dart';

void main() {
  testWidgets('Splash shows the logo, then hands over', (WidgetTester tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(home: SplashScreen(onComplete: () => done = true)));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('SUDOKU'), findsWidgets);
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(done, isTrue);
  });
}
