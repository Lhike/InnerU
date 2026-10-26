import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_tracker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CalorieTrackerScreen()));
    // Network calls fail fast in tests; let loading finish.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

  String text(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> pickChickenBreast(WidgetTester tester) async {
    await tester.ensureVisible(field('Food Name'));
    await tester.enterText(field('Food Name'), 'chicken');
    await tester.pump();
    await tester.tap(find.text('Chicken Breast').last);
    await tester.pump();
  }

  testWidgets('typing a multi-digit amount rescales without rewriting the name',
      (tester) async {
    await pumpScreen(tester);
    await pickChickenBreast(tester);

    expect(text(tester, 'Food Name'), 'Chicken Breast');
    expect(text(tester, 'Amount'), '100');
    expect(text(tester, 'Calories'), '165');

    await tester.enterText(field('Amount'), '2');
    await tester.pump();
    await tester.enterText(field('Amount'), '25');
    await tester.pump();
    await tester.enterText(field('Amount'), '250');
    await tester.pump();

    expect(text(tester, 'Amount'), '250');
    expect(text(tester, 'Food Name'), 'Chicken Breast');
    expect(text(tester, 'Calories'), '413');
    expect(text(tester, 'Protein'), '78');
  });

  testWidgets('changing the food name drops the old food’s calories',
      (tester) async {
    await pumpScreen(tester);
    await pickChickenBreast(tester);
    expect(text(tester, 'Calories'), '165');

    await tester.enterText(field('Food Name'), 'Chicken Breast adobo');
    await tester.pump();

    expect(text(tester, 'Food Name'), 'Chicken Breast adobo');
    expect(text(tester, 'Calories'), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('calories typed by hand are kept when the name changes',
      (tester) async {
    await pumpScreen(tester);
    await pickChickenBreast(tester);

    await tester.enterText(field('Calories'), '300');
    await tester.pump();
    await tester.enterText(field('Food Name'), 'Grilled chicken');
    await tester.pump();

    expect(text(tester, 'Calories'), '300');
    await tester.pump(const Duration(seconds: 2));
  });
}
