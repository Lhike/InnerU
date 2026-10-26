import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum WalkerHairStyle {
  short('Short'),
  long('Long'),
  ponytail('Ponytail'),
  bun('Bun'),
  curly('Curly'),
  buzz('Buzz cut');

  const WalkerHairStyle(this.label);
  final String label;
}

enum WalkerTop {
  tee('T-shirt'),
  hoodie('Hoodie'),
  tank('Tank top');

  const WalkerTop(this.label);
  final String label;
}

enum WalkerBottom {
  pants('Pants'),
  shorts('Shorts');

  const WalkerBottom(this.label);
  final String label;
}

enum WalkerAccessory {
  none('None'),
  backpack('Backpack'),
  cap('Cap'),
  headphones('Headphones'),
  crown('Crown');

  const WalkerAccessory(this.label);
  final String label;
}

/// How the user's walker looks. Stored as JSON on the device.
@immutable
class WalkerLook {
  const WalkerLook({
    this.skinTone = const Color(0xFFE0A47E),
    this.hairStyle = WalkerHairStyle.short,
    this.hairColor = const Color(0xFF3B2416),
    this.top = WalkerTop.tee,
    this.topColor = const Color(0xFFE040FB),
    this.bottom = WalkerBottom.pants,
    this.bottomColor = const Color(0xFF37474F),
    this.shoeColor = const Color(0xFFF5F5F5),
    this.accessory = WalkerAccessory.backpack,
  });

  final Color skinTone;
  final WalkerHairStyle hairStyle;
  final Color hairColor;
  final WalkerTop top;
  final Color topColor;
  final WalkerBottom bottom;
  final Color bottomColor;
  final Color shoeColor;
  final WalkerAccessory accessory;

  static const skinTones = <Color>[
    Color(0xFFFFDBC4),
    Color(0xFFF1C27D),
    Color(0xFFE0A47E),
    Color(0xFFC68642),
    Color(0xFF8D5524),
    Color(0xFF5C3A21),
  ];

  static const hairColors = <Color>[
    Color(0xFF1B1B1B),
    Color(0xFF3B2416),
    Color(0xFF7B4A2A),
    Color(0xFFE6C36A),
    Color(0xFFB5452B),
    Color(0xFFBDBDBD),
    Color(0xFFF06292),
    Color(0xFF42A5F5),
  ];

  static const clothingColors = <Color>[
    Color(0xFFE040FB),
    Color(0xFF29B6F6),
    Color(0xFF9CCC65),
    Color(0xFFFF7043),
    Color(0xFF7C4DFF),
    Color(0xFFFFC93C),
    Color(0xFFEF5350),
    Color(0xFF26A69A),
    Color(0xFF37474F),
    Color(0xFFF5F5F5),
    Color(0xFF1B1B1B),
    Color(0xFF8D6E63),
  ];

  WalkerLook copyWith({
    Color? skinTone,
    WalkerHairStyle? hairStyle,
    Color? hairColor,
    WalkerTop? top,
    Color? topColor,
    WalkerBottom? bottom,
    Color? bottomColor,
    Color? shoeColor,
    WalkerAccessory? accessory,
  }) {
    return WalkerLook(
      skinTone: skinTone ?? this.skinTone,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      top: top ?? this.top,
      topColor: topColor ?? this.topColor,
      bottom: bottom ?? this.bottom,
      bottomColor: bottomColor ?? this.bottomColor,
      shoeColor: shoeColor ?? this.shoeColor,
      accessory: accessory ?? this.accessory,
    );
  }

  /// A random look, using only accessories in [allowedAccessories].
  factory WalkerLook.random(
    math.Random random, {
    Iterable<WalkerAccessory> allowedAccessories = WalkerAccessory.values,
  }) {
    T pick<T>(List<T> items) => items[random.nextInt(items.length)];
    return WalkerLook(
      skinTone: pick(skinTones),
      hairStyle: pick(WalkerHairStyle.values),
      hairColor: pick(hairColors),
      top: pick(WalkerTop.values),
      topColor: pick(clothingColors),
      bottom: pick(WalkerBottom.values),
      bottomColor: pick(clothingColors),
      shoeColor: pick(clothingColors),
      accessory: pick(allowedAccessories.toList()),
    );
  }

  /// The shape shared with the API and saved on the device.
  Map<String, dynamic> toMap() => {
        'skin': skinTone.toARGB32(),
        'hairStyle': hairStyle.name,
        'hair': hairColor.toARGB32(),
        'top': top.name,
        'topColor': topColor.toARGB32(),
        'bottom': bottom.name,
        'bottomColor': bottomColor.toARGB32(),
        'shoes': shoeColor.toARGB32(),
        'accessory': accessory.name,
      };

  String toJson() => jsonEncode(toMap());

  /// Parses a saved look; anything missing or invalid keeps its default.
  static WalkerLook fromMap(Map<String, dynamic> json) {
    const fallback = WalkerLook();

    Color color(String key, Color orElse) {
      final value = json[key];
      return value is int ? Color(value) : orElse;
    }

    T named<T extends Enum>(List<T> values, String key, T orElse) {
      final value = json[key];
      return values.firstWhere((v) => v.name == value, orElse: () => orElse);
    }

    return WalkerLook(
      skinTone: color('skin', fallback.skinTone),
      hairStyle: named(WalkerHairStyle.values, 'hairStyle', fallback.hairStyle),
      hairColor: color('hair', fallback.hairColor),
      top: named(WalkerTop.values, 'top', fallback.top),
      topColor: color('topColor', fallback.topColor),
      bottom: named(WalkerBottom.values, 'bottom', fallback.bottom),
      bottomColor: color('bottomColor', fallback.bottomColor),
      shoeColor: color('shoes', fallback.shoeColor),
      accessory: named(WalkerAccessory.values, 'accessory', fallback.accessory),
    );
  }

  static WalkerLook fromJson(String? source) {
    if (source == null || source.isEmpty) return const WalkerLook();
    try {
      final decoded = jsonDecode(source);
      return decoded is Map
          ? fromMap(decoded.cast<String, dynamic>())
          : const WalkerLook();
    } on FormatException {
      return const WalkerLook();
    }
  }

  /// Converts the old single-colour skins so nobody loses their pick.
  static WalkerLook fromLegacySkin(String? skinId) {
    const base = WalkerLook();
    return switch (skinId) {
      'ocean' => base.copyWith(topColor: const Color(0xFF29B6F6)),
      'lime' => base.copyWith(topColor: const Color(0xFF9CCC65)),
      'sporty' => base.copyWith(
          topColor: const Color(0xFFFF7043),
          accessory: WalkerAccessory.cap,
        ),
      'dj' => base.copyWith(
          topColor: const Color(0xFF7C4DFF),
          top: WalkerTop.hoodie,
          accessory: WalkerAccessory.headphones,
        ),
      'champion' => base.copyWith(
          topColor: const Color(0xFFFFC93C),
          accessory: WalkerAccessory.crown,
        ),
      _ => base,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is WalkerLook && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}

/// An animated walking person drawn from [look]. [phase] runs 0..1 per
/// stride; [blink] closes the eyes for a frame.
class WalkerAvatar extends StatelessWidget {
  const WalkerAvatar({
    super.key,
    required this.look,
    required this.phase,
    this.blink = false,
  });

  final WalkerLook look;
  final double phase;
  final bool blink;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: WalkerPainter(look: look, phase: phase, blink: blink),
    );
  }
}

class WalkerPainter extends CustomPainter {
  WalkerPainter({required this.look, required this.phase, this.blink = false});

  final WalkerLook look;
  final double phase;
  final bool blink;

  static Color _shade(Color color, double amount) =>
      Color.lerp(color, Colors.black, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    // The figure is about 0.8 wide per 1 tall; fit it in the box.
    final h = math.min(size.height, size.width / 0.8);
    canvas.save();
    canvas.translate((size.width - h * 0.8) / 2, size.height - h);

    final p = phase * 2 * math.pi;
    final bob = -math.cos(p * 2).abs() * h * 0.012;
    final hip = Offset(h * 0.38, h * 0.53 + bob);
    const lean = 0.1;
    final torsoLength = h * 0.27;
    final shoulderTop = hip +
        Offset(math.sin(lean) * torsoLength, -math.cos(lean) * torsoLength);
    final headCenter = shoulderTop + Offset(h * 0.035, -h * 0.125);
    final headRadius = h * 0.1;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(h * 0.42, h * 0.975),
        width: h * 0.36,
        height: h * 0.035,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    _drawArm(canvas, h, shoulderTop, p + math.pi, near: false);
    _drawLeg(canvas, h, hip, p + math.pi, near: false);
    if (look.hairStyle == WalkerHairStyle.long ||
        look.hairStyle == WalkerHairStyle.ponytail) {
      _drawHairBack(canvas, headCenter, headRadius, p);
    }
    if (look.accessory == WalkerAccessory.backpack) {
      _drawBackpack(canvas, h, hip, lean);
    }
    _drawHips(canvas, h, hip, lean);
    _drawLeg(canvas, h, hip, p, near: true);
    _drawTorso(canvas, h, hip, lean);
    _drawNeck(canvas, h, shoulderTop, headCenter);
    _drawHead(canvas, headCenter, headRadius);
    _drawArm(canvas, h, shoulderTop, p, near: true);

    canvas.restore();
  }

  Offset _along(Offset from, double angle, double length) =>
      from + Offset(math.sin(angle) * length, math.cos(angle) * length);

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _drawLeg(
    Canvas canvas,
    double h,
    Offset hip,
    double p, {
    required bool near,
  }) {
    final swing = math.sin(p) * 0.5;
    final bend = 0.08 + 0.85 * math.max(0.0, math.cos(p));
    final knee = _along(hip, swing, h * 0.2);
    final shinAngle = swing - bend;
    final ankle = _along(knee, shinAngle, h * 0.21);

    final dim = near ? 0.0 : 0.22;
    final skin = _shade(look.skinTone, dim);
    final cloth = _shade(look.bottomColor, dim);

    if (look.bottom == WalkerBottom.pants) {
      canvas.drawLine(hip, knee, _stroke(cloth, h * 0.095));
      canvas.drawLine(knee, ankle, _stroke(cloth, h * 0.08));
    } else {
      final hem = Offset.lerp(hip, knee, 0.75)!;
      canvas.drawLine(knee, ankle, _stroke(skin, h * 0.068));
      canvas.drawLine(hem, knee, _stroke(skin, h * 0.078));
      canvas.drawLine(hip, hem, _stroke(cloth, h * 0.1));
    }

    // Shoe, tipping toe-down as the foot lifts behind.
    canvas.save();
    canvas.translate(ankle.dx, ankle.dy);
    canvas.rotate(-shinAngle * 0.6);
    final shoe = _shade(look.shoeColor, dim);
    canvas.drawRRect(
      RRect.fromLTRBR(-h * 0.03, -h * 0.022, h * 0.08, h * 0.03,
          Radius.circular(h * 0.024)),
      Paint()..color = shoe,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
          -h * 0.03, h * 0.017, h * 0.08, h * 0.03, Radius.circular(h * 0.01)),
      Paint()
        ..color = look.shoeColor.computeLuminance() > 0.6
            ? _shade(look.shoeColor, 0.35)
            : Colors.white.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  void _drawArm(
    Canvas canvas,
    double h,
    Offset shoulderTop,
    double p, {
    required bool near,
  }) {
    final shoulder = shoulderTop + Offset(-h * 0.005, h * 0.03);
    final swing = -math.sin(p) * 0.55;
    final elbow = _along(shoulder, swing, h * 0.135);
    final wrist = _along(elbow, swing + 0.75, h * 0.12);

    final dim = near ? 0.0 : 0.22;
    final skin = _shade(look.skinTone, dim);
    final sleeve = _shade(look.topColor, dim);

    switch (look.top) {
      case WalkerTop.tank:
        canvas.drawLine(shoulder, elbow, _stroke(skin, h * 0.055));
        canvas.drawLine(elbow, wrist, _stroke(skin, h * 0.048));
      case WalkerTop.tee:
        final cuff = Offset.lerp(shoulder, elbow, 0.6)!;
        canvas.drawLine(cuff, elbow, _stroke(skin, h * 0.052));
        canvas.drawLine(elbow, wrist, _stroke(skin, h * 0.048));
        canvas.drawLine(shoulder, cuff, _stroke(sleeve, h * 0.07));
      case WalkerTop.hoodie:
        canvas.drawLine(shoulder, elbow, _stroke(sleeve, h * 0.066));
        canvas.drawLine(elbow, wrist, _stroke(sleeve, h * 0.058));
    }
    canvas.drawCircle(wrist, h * 0.03, Paint()..color = skin);
  }

  void _drawHips(Canvas canvas, double h, Offset hip, double lean) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(lean);
    canvas.drawRRect(
      RRect.fromLTRBR(-h * 0.07, -h * 0.045, h * 0.065, h * 0.04,
          Radius.circular(h * 0.035)),
      Paint()..color = look.bottomColor,
    );
    canvas.restore();
  }

  void _drawTorso(Canvas canvas, double h, Offset hip, double lean) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(lean);
    final color = look.topColor;
    final dark = _shade(color, 0.18);

    if (look.top == WalkerTop.hoodie) {
      // Hood resting on the back.
      canvas.drawCircle(
          Offset(-h * 0.06, -h * 0.25), h * 0.05, Paint()..color = dark);
    }

    final shirt = look.top == WalkerTop.tank
        ? RRect.fromLTRBAndCorners(-h * 0.066, -h * 0.25, h * 0.06, h * 0.005,
            topLeft: Radius.circular(h * 0.03),
            topRight: Radius.circular(h * 0.03),
            bottomLeft: Radius.circular(h * 0.025),
            bottomRight: Radius.circular(h * 0.025))
        : RRect.fromLTRBAndCorners(-h * 0.077, -h * 0.275, h * 0.072,
            look.top == WalkerTop.hoodie ? h * 0.018 : h * 0.005,
            topLeft: Radius.circular(h * 0.06),
            topRight: Radius.circular(h * 0.06),
            bottomLeft: Radius.circular(h * 0.03),
            bottomRight: Radius.circular(h * 0.03));
    canvas.drawRRect(shirt, Paint()..color = color);

    // A soft shade down the back for some volume.
    canvas.save();
    canvas.clipRRect(shirt);
    canvas.drawRect(
      Rect.fromLTRB(-h * 0.08, -h * 0.28, -h * 0.045, h * 0.03),
      Paint()..color = dark.withValues(alpha: 0.6),
    );
    canvas.restore();

    switch (look.top) {
      case WalkerTop.hoodie:
        canvas.drawRRect(
          RRect.fromLTRBR(-h * 0.03, -h * 0.095, h * 0.055, -h * 0.03,
              Radius.circular(h * 0.015)),
          Paint()..color = dark,
        );
        final string = _stroke(Colors.white.withValues(alpha: 0.85), h * 0.008);
        canvas.drawLine(
            Offset(h * 0.035, -h * 0.25), Offset(h * 0.035, -h * 0.19), string);
        canvas.drawLine(
            Offset(h * 0.05, -h * 0.25), Offset(h * 0.05, -h * 0.2), string);
      case WalkerTop.tee:
        canvas.drawLine(
          Offset(-h * 0.075, -h * 0.004),
          Offset(h * 0.07, -h * 0.004),
          _stroke(dark, h * 0.012),
        );
      case WalkerTop.tank:
        break;
    }
    canvas.restore();
  }

  void _drawNeck(
      Canvas canvas, double h, Offset shoulderTop, Offset headCenter) {
    canvas.drawLine(
      shoulderTop + Offset(h * 0.008, h * 0.01),
      headCenter + Offset(-h * 0.006, h * 0.06),
      _stroke(_shade(look.skinTone, 0.12), h * 0.045),
    );
  }

  void _drawBackpack(Canvas canvas, double h, Offset hip, double lean) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(lean);
    const pack = Color(0xFF6D6A5C);
    canvas.drawRRect(
      RRect.fromLTRBR(-h * 0.135, -h * 0.25, -h * 0.045, -h * 0.06,
          Radius.circular(h * 0.035)),
      Paint()..color = pack,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(-h * 0.13, -h * 0.14, -h * 0.07, -h * 0.08,
          Radius.circular(h * 0.015)),
      Paint()..color = _shade(pack, 0.2),
    );
    canvas.restore();
  }

  void _drawHairBack(Canvas canvas, Offset c, double r, double p) {
    final paint = Paint()..color = _shade(look.hairColor, 0.12);
    if (look.hairStyle == WalkerHairStyle.long) {
      canvas.drawRRect(
        RRect.fromLTRBR(c.dx - r * 1.12, c.dy - r * 0.4, c.dx + r * 0.15,
            c.dy + r * 1.55, Radius.circular(r * 0.55)),
        paint,
      );
    } else {
      // Ponytail swinging with each step.
      final sway = math.sin(p * 2) * 0.25;
      canvas.save();
      canvas.translate(c.dx - r * 0.95, c.dy - r * 0.15);
      canvas.rotate(0.5 + sway);
      canvas.drawOval(
        Rect.fromLTWH(-r * 0.32, 0, r * 0.62, r * 1.25),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawHead(Canvas canvas, Offset c, double r) {
    final skin = look.skinTone;
    final hair = Paint()..color = look.hairColor;

    if (look.hairStyle == WalkerHairStyle.bun) {
      canvas.drawCircle(c + Offset(-r * 0.55, -r * 0.95), r * 0.45, hair);
    }

    // Ear, head.
    canvas.drawCircle(c, r, Paint()..color = skin);
    canvas.drawCircle(c + Offset(-r * 0.12, r * 0.12), r * 0.2,
        Paint()..color = _shade(skin, 0.12));

    _drawHairTop(canvas, c, r, hair);
    _drawFace(canvas, c, r);
    _drawHeadwear(canvas, c, r);
  }

  void _drawHairTop(Canvas canvas, Offset c, double r, Paint hair) {
    switch (look.hairStyle) {
      case WalkerHairStyle.curly:
        for (var degrees = 100; degrees <= 330; degrees += 23) {
          final angle = degrees * math.pi / 180;
          canvas.drawCircle(
            c + Offset(math.cos(angle) * r * 0.92, math.sin(angle) * r * 0.92),
            r * 0.36,
            hair,
          );
        }
      case WalkerHairStyle.buzz:
        _hairCap(
            canvas, c, r, hair..color = look.hairColor.withValues(alpha: 0.75),
            scale: 1.0, fringe: false);
      case WalkerHairStyle.short:
      case WalkerHairStyle.long:
      case WalkerHairStyle.ponytail:
      case WalkerHairStyle.bun:
        _hairCap(canvas, c, r, hair, scale: 1.08, fringe: true);
    }
  }

  /// Hair over the top and back of the head, leaving the face clear.
  void _hairCap(
    Canvas canvas,
    Offset c,
    double r,
    Paint paint, {
    required double scale,
    required bool fringe,
  }) {
    final head = Path()..addOval(Rect.fromCircle(center: c, radius: r * scale));
    final region = Path()
      ..addRect(Rect.fromLTRB(
          c.dx - r * 1.3, c.dy - r * 1.3, c.dx + r * 1.3, c.dy - r * 0.3))
      ..addRect(Rect.fromLTRB(
          c.dx - r * 1.3, c.dy - r * 1.3, c.dx - r * 0.25, c.dy + r * 0.3));
    canvas.drawPath(Path.combine(PathOperation.intersect, head, region), paint);
    if (fringe) {
      final bangs = Path()
        ..moveTo(c.dx + r * 0.1, c.dy - r * 0.35)
        ..quadraticBezierTo(
            c.dx + r * 0.65, c.dy - r * 0.15, c.dx + r * 0.95, c.dy - r * 0.42)
        ..lineTo(c.dx + r * 0.8, c.dy - r * 0.75)
        ..close();
      canvas.drawPath(bangs, paint);
    }
  }

  void _drawFace(Canvas canvas, Offset c, double r) {
    final ink = Paint()..color = const Color(0xFF2B1B14);
    final eyes = [
      (c + Offset(r * 0.38, -r * 0.05), r * 0.13),
      (c + Offset(r * 0.74, -r * 0.05), r * 0.1),
    ];
    for (final (center, size) in eyes) {
      if (blink) {
        canvas.drawLine(center - Offset(size * 0.8, 0),
            center + Offset(size * 0.8, 0), _stroke(ink.color, r * 0.06));
      } else {
        canvas.drawOval(
          Rect.fromCenter(
              center: center, width: size * 1.3, height: size * 1.8),
          ink,
        );
        canvas.drawCircle(center + Offset(size * 0.22, -size * 0.35),
            size * 0.3, Paint()..color = Colors.white);
      }
    }

    // Brow, nose, smile, blush.
    canvas.drawLine(c + Offset(r * 0.3, -r * 0.33),
        c + Offset(r * 0.55, -r * 0.36), _stroke(look.hairColor, r * 0.07));
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(r * 0.9, r * 0.14), radius: r * 0.08),
      -math.pi / 2,
      math.pi,
      false,
      _stroke(_shade(look.skinTone, 0.25), r * 0.05),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(r * 0.58, r * 0.3), radius: r * 0.2),
      0.25,
      math.pi - 0.7,
      false,
      _stroke(const Color(0xFF8E3B2E), r * 0.07),
    );
    canvas.drawCircle(c + Offset(r * 0.3, r * 0.3), r * 0.13,
        Paint()..color = const Color(0xFFFF6F61).withValues(alpha: 0.3));
  }

  void _drawHeadwear(Canvas canvas, Offset c, double r) {
    switch (look.accessory) {
      case WalkerAccessory.none:
      case WalkerAccessory.backpack:
        return;
      case WalkerAccessory.cap:
        final cap = Paint()..color = const Color(0xFF263238);
        canvas.drawArc(
          Rect.fromCircle(center: c + Offset(0, -r * 0.12), radius: r * 1.06),
          math.pi,
          math.pi,
          true,
          cap,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(c.dx + r * 0.2, c.dy - r * 0.22, c.dx + r * 1.55,
              c.dy - r * 0.06, Radius.circular(r * 0.08)),
          cap,
        );
      case WalkerAccessory.headphones:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 1.18),
          math.pi * 1.05,
          math.pi * 0.9,
          false,
          _stroke(const Color(0xFF212121), r * 0.22),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + Offset(-r * 0.12, r * 0.1),
                width: r * 0.55,
                height: r * 0.8),
            Radius.circular(r * 0.25),
          ),
          Paint()..color = const Color(0xFF00E5FF),
        );
      case WalkerAccessory.crown:
        final top = c.dy - r * 0.85;
        final crown = Path()
          ..moveTo(c.dx - r * 0.75, top)
          ..lineTo(c.dx - r * 0.75, top - r * 0.85)
          ..lineTo(c.dx - r * 0.38, top - r * 0.42)
          ..lineTo(c.dx, top - r * 1.05)
          ..lineTo(c.dx + r * 0.38, top - r * 0.42)
          ..lineTo(c.dx + r * 0.75, top - r * 0.85)
          ..lineTo(c.dx + r * 0.75, top)
          ..close();
        canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD54F));
        canvas.drawPath(crown, _stroke(const Color(0xFFB8860B), r * 0.08));
    }
  }

  @override
  bool shouldRepaint(WalkerPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.blink != blink ||
      oldDelegate.look != look;
}
