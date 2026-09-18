import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';

void main() {
  testWidgets('A12 header avatar stays compact and opens its menu',
      (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AbundanceHeaderProfileButton(
                initials: 'A',
                profilePic: '',
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );

    final control = find.byKey(
      const ValueKey('abundance-header-profile-menu'),
    );
    expect(tester.getSize(control).height, lessThanOrEqualTo(48));

    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('Profile & settings'));
    await tester.pumpAndSettle();
    expect(selected, 'profile');

    await tester.tap(control);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(selected, 'notifications');

    await tester.tap(control);
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(selected, 'more');
  });
}
