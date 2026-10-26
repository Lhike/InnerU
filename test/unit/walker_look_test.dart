import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';

void main() {
  test('a look round-trips through JSON', () {
    const look = WalkerLook(
      skinTone: Color(0xFF8D5524),
      hairStyle: WalkerHairStyle.curly,
      hairColor: Color(0xFFF06292),
      top: WalkerTop.tank,
      topColor: Color(0xFF26A69A),
      bottom: WalkerBottom.shorts,
      bottomColor: Color(0xFF1B1B1B),
      shoeColor: Color(0xFFFFC93C),
      accessory: WalkerAccessory.crown,
    );
    expect(WalkerLook.fromJson(look.toJson()), look);
  });

  test('broken or partial saves fall back to defaults', () {
    expect(WalkerLook.fromJson(null), const WalkerLook());
    expect(WalkerLook.fromJson('not json'), const WalkerLook());
    final partial = WalkerLook.fromJson('{"hairStyle":"bun","top":"cape"}');
    expect(partial.hairStyle, WalkerHairStyle.bun);
    expect(partial.top, const WalkerLook().top);
  });

  test('legacy skins map onto the new look', () {
    expect(
        WalkerLook.fromLegacySkin('champion').accessory, WalkerAccessory.crown);
    expect(WalkerLook.fromLegacySkin('sporty').accessory, WalkerAccessory.cap);
    expect(WalkerLook.fromLegacySkin(null), const WalkerLook());
  });

  test('random looks only use allowed accessories', () {
    final random = math.Random(1);
    for (var i = 0; i < 50; i++) {
      final look = WalkerLook.random(
        random,
        allowedAccessories: const [WalkerAccessory.none],
      );
      expect(look.accessory, WalkerAccessory.none);
    }
  });

  testWidgets('every combination paints without errors', (tester) async {
    for (final hair in WalkerHairStyle.values) {
      for (final top in WalkerTop.values) {
        for (final accessory in WalkerAccessory.values) {
          await tester.pumpWidget(SizedBox(
            width: 160,
            height: 200,
            child: WalkerAvatar(
              look: WalkerLook(
                hairStyle: hair,
                top: top,
                bottom: hair.index.isEven
                    ? WalkerBottom.pants
                    : WalkerBottom.shorts,
                accessory: accessory,
              ),
              phase: (hair.index + top.index) / 10,
              blink: accessory.index.isOdd,
            ),
          ));
        }
      }
    }
    expect(tester.takeException(), isNull);
  });
}
