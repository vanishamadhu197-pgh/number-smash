import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NumberMatchGameApp());
}

class NumberMatchGameApp extends StatelessWidget {
  const NumberMatchGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Smash',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color.fromARGB(255, 48, 48, 117),
        fontFamily: 'Inter',
      ),
      debugShowCheckedModeBanner: false,
      home: const GameScreen(),
    );
  }
}

// ─── Level Config ─────────────────────────────────────────────────────────
class LevelConfig {
  final int level;
  final int maxNumber;
  final int closeThreshold;
  final String label;
  final Color bgTop;
  final Color bgBottom;
  final Color accent;
  final String emoji;
    final int lives;
  const LevelConfig({required this.level, required this.maxNumber,
      required this.closeThreshold, required this.label,
      required this.bgTop, required this.bgBottom, required this.accent, required this.emoji, required this.lives});
}

const List<LevelConfig> levels = [
    LevelConfig(level: 1, maxNumber: 9,  closeThreshold: 2,  label: 'EASY',
      bgTop: Color(0xFF6C3FE8), bgBottom: Color(0xFF3B9EFF), accent: Color(0xFFFFD700), emoji: '⭐', lives: 3),
    LevelConfig(level: 2, maxNumber: 49, closeThreshold: 5,  label: 'MEDIUM',
      bgTop: Color(0xFFFF6B6B), bgBottom: Color(0xFFFF8E53), accent: Color(0xFFFFFF00), emoji: '🔥', lives: 5),
    LevelConfig(level: 3, maxNumber: 99, closeThreshold: 10, label: 'HARD',
      bgTop: Color(0xFF1A1A2E), bgBottom: Color(0xFF6C3FE8), accent: Color(0xFF00FFD1), emoji: '💎', lives: 3),
];

enum GamePhase { entry, picking, rolling, result, levelUp, champion }
enum AlexMood { idle, thinking, happy, sad, surprised }

// ─── Confetti ─────────────────────────────────────────────────────────────
class Particle {
  double x, y, vx, vy, size, opacity, rotation;
  Color color;
  int shape; // 0=circle, 1=rect, 2=star
  Particle({required this.x, required this.y, required this.vx, required this.vy,
      required this.size, required this.opacity, required this.color, required this.rotation, required this.shape});
}

class ConfettiPainter extends CustomPainter {
  final List<Particle> particles;
  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      if (p.shape == 0) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == 1) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      } else {
        _drawStar(canvas, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a1 = (i * 72 - 90) * pi / 180;
      final a2 = (i * 72 - 90 + 36) * pi / 180;
      if (i == 0) {
        path.moveTo(cos(a1) * r, sin(a1) * r);
      } else {
        path.lineTo(cos(a1) * r, sin(a1) * r);
      }
      path.lineTo(cos(a2) * r * 0.4, sin(a2) * r * 0.4);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => true;
}

class ConfettiOverlay extends StatefulWidget {
  final bool active;
  const ConfettiOverlay({super.key, required this.active});
  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Particle> _particles = [];
  final _rng = Random();
  Timer? _timer;

  static const _colors = [
    Color(0xFFFFD700), Color(0xFFFF6B6B), Color(0xFF00FFD1),
    Color(0xFFFF9EFF), Color(0xFF7BFF7B), Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
    if (!widget.active) { _timer?.cancel(); _ctrl.stop(); setState(() => _particles.clear()); }
  }

  void _start() {
    _particles.clear();
    _ctrl.forward(from: 0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !widget.active) { timer.cancel(); return; }
      setState(() {
        if (_particles.length < 120 && _ctrl.value < 0.6) {
          final w = MediaQuery.of(context).size.width;
          for (int i = 0; i < 4; i++) {
            _particles.add(Particle(
              x: _rng.nextDouble() * w, y: -10,
              vx: (_rng.nextDouble() - 0.5) * 5,
              vy: _rng.nextDouble() * 4 + 2,
              size: _rng.nextDouble() * 12 + 6,
              opacity: 1, rotation: _rng.nextDouble() * pi * 2,
              color: _colors[_rng.nextInt(_colors.length)],
              shape: _rng.nextInt(3),
            ));
          }
        }
        for (final p in _particles) {
          p.x += p.vx; p.y += p.vy; p.vy += 0.12;
          p.rotation += p.vx * 0.05; p.opacity -= 0.004;
        }
        _particles.removeWhere((p) => p.opacity <= 0);
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox.expand(child: CustomPaint(painter: ConfettiPainter(_particles))),
    );
  }
}

// ─── Cartoon Background Painter ────────────────────────────────────────────
class BgPainter extends CustomPainter {
  final Color topColor, bottomColor;
  final double animVal;
  BgPainter({required this.topColor, required this.bottomColor, required this.animVal});

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient sky
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [topColor, bottomColor],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Ground
    final groundPaint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRect(Rect.fromLTWH(0, size.height - 60, size.width, 60), groundPaint);

    // Stars / dots
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    final rng = Random(42);
    for (int i = 0; i < 20; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final r = rng.nextDouble() * 3 + 1;
      final pulse = sin((animVal * 2 * pi) + i) * 0.5 + 0.5;
      canvas.drawCircle(Offset(x, y), r * (0.5 + pulse * 0.5),
          Paint()..color = Colors.white.withValues(alpha: 0.15 + pulse * 0.3));
    }

    // Clouds
    _drawCloud(canvas, size.width * 0.15 + sin(animVal * 2 * pi) * 10, size.height * 0.12, 0.8);
    _drawCloud(canvas, size.width * 0.75 + cos(animVal * 2 * pi) * 8, size.height * 0.2, 1.0);
    _drawCloud(canvas, size.width * 0.5 + sin(animVal * 2 * pi + 1) * 12, size.height * 0.05, 0.6);
  }

  void _drawCloud(Canvas canvas, double x, double y, double scale) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawCircle(Offset(x, y), 22 * scale, p);
    canvas.drawCircle(Offset(x + 18 * scale, y + 4 * scale), 16 * scale, p);
    canvas.drawCircle(Offset(x - 16 * scale, y + 4 * scale), 14 * scale, p);
  }

  @override
  bool shouldRepaint(BgPainter old) => true;
}

// ─── PENGUIN Cartoon Character ─────────────────────────────────────────────
class CartoonAlexPainter extends CustomPainter {
  final double bob, blink, armWave, mouthAnim;
  final AlexMood mood;
  final Color color;

  CartoonAlexPainter({required this.bob, required this.blink, required this.armWave,
      required this.mouthAnim, required this.mood, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + bob * 5;

    // Penguin colors
    const darkBody = Color(0xFF1C1C2E);
    const bellyWhite = Color(0xFFF5F0E8);
    const beakOrange = Color(0xFFFF9800);
    const feetOrange = Color(0xFFFF8C00);

    // Soft shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 52), width: 80, height: 18),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // ── Feet (orange, behind body) ──
    // Left foot
    final leftFootPath = Path();
    leftFootPath.addOval(Rect.fromCenter(
      center: Offset(cx - 14, cy + 48), width: 24, height: 10));
    canvas.drawPath(leftFootPath, Paint()..color = feetOrange);
    canvas.drawPath(leftFootPath, Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Right foot
    final rightFootPath = Path();
    rightFootPath.addOval(Rect.fromCenter(
      center: Offset(cx + 14, cy + 48), width: 24, height: 10));
    canvas.drawPath(rightFootPath, Paint()..color = feetOrange);
    canvas.drawPath(rightFootPath, Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // ── Body (dark, egg-shaped) ──
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy + 18), width: 72, height: 62);
    final bodyPaint = Paint()..shader = RadialGradient(
      colors: [const Color(0xFF2A2A3E), darkBody],
      center: const Alignment(0, -0.4),
      radius: 1.0,
    ).createShader(bodyRect);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(30));
    canvas.drawRRect(bodyRRect, bodyPaint);
    canvas.drawRRect(bodyRRect, Paint()..color = Colors.black.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 2);

    // ── Belly (white oval) ──
    final bellyPath = Path();
    bellyPath.addOval(Rect.fromCenter(center: Offset(cx, cy + 22), width: 44, height: 40));
    canvas.drawPath(bellyPath, Paint()..color = bellyWhite);
    canvas.drawPath(bellyPath, Paint()..color = Colors.black.withValues(alpha: 0.06)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Subtle belly shading
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 28), width: 30, height: 20),
      Paint()..color = const Color(0xFFE8E0D0).withValues(alpha: 0.5),
    );

    // ── Flippers (wings) ──
    final leftFlipAngle = mood == AlexMood.happy ? -0.3 + armWave * 0.6 : -0.05;
    final rightFlipAngle = mood == AlexMood.happy ? 0.3 - armWave * 0.6 : 0.05;
    _drawFlipper(canvas, cx, cy, leftFlipAngle, true, darkBody);
    _drawFlipper(canvas, cx, cy, rightFlipAngle, false, darkBody);

    // ── Head (dark, round) ──
    final headRect = Rect.fromCircle(center: Offset(cx, cy - 10), radius: 32);
    final headPaint = Paint()..shader = RadialGradient(
      colors: [const Color(0xFF2A2A3E), darkBody],
      center: const Alignment(0, -0.5),
      radius: 1.2,
    ).createShader(headRect);
    canvas.drawCircle(Offset(cx, cy - 10), 32, headPaint);
    canvas.drawCircle(Offset(cx, cy - 10), 32, Paint()..color = Colors.black.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 2.2);

    // ── White face patches (like real penguin eye patches) ──
    final leftPatch = Path();
    leftPatch.addOval(Rect.fromCenter(center: Offset(cx - 10, cy - 14), width: 20, height: 22));
    canvas.drawPath(leftPatch, Paint()..color = bellyWhite);
    final rightPatch = Path();
    rightPatch.addOval(Rect.fromCenter(center: Offset(cx + 10, cy - 14), width: 20, height: 22));
    canvas.drawPath(rightPatch, Paint()..color = bellyWhite);

    // ── Little floating heart when happy (above head) ──
    if (mood == AlexMood.happy) {
      _drawHeart(canvas, Offset(cx + 8, cy - 58), 10, Paint()..color = const Color(0xFFFF6B6B)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // ── Eyes ──
    _drawPenguinEye(canvas, cx - 10, cy - 14, blink, mood, mouthAnim);
    _drawPenguinEye(canvas, cx + 10, cy - 14, blink, mood, mouthAnim);

    // ── Cheeks (soft rosy) ──
    canvas.drawCircle(Offset(cx - 20, cy - 4), 6, Paint()..color = const Color(0xFFFFB3BA).withValues(alpha: mood == AlexMood.sad ? 0.25 : 0.5));
    canvas.drawCircle(Offset(cx + 20, cy - 4), 6, Paint()..color = const Color(0xFFFFB3BA).withValues(alpha: mood == AlexMood.sad ? 0.25 : 0.5));

    // ── Beak (orange triangle) ──
    _drawBeak(canvas, cx, cy + 1, mood, mouthAnim);

    // ── Bow tie (cute accent, uses level color) ──
    _drawBowTie(canvas, cx, cy + 4, color);
  }

  void _drawFlipper(Canvas canvas, double cx, double cy, double angle, bool isLeft, Color bodyColor) {
    canvas.save();
    final px = isLeft ? cx - 34 : cx + 34;
    final py = cy + 10;
    canvas.translate(px, py);
    canvas.rotate(angle);

    final flipPath = Path();
    if (isLeft) {
      flipPath.moveTo(0, -12);
      flipPath.quadraticBezierTo(-18, 0, -8, 22);
      flipPath.quadraticBezierTo(-2, 24, 4, 18);
      flipPath.quadraticBezierTo(6, 6, 0, -12);
    } else {
      flipPath.moveTo(0, -12);
      flipPath.quadraticBezierTo(18, 0, 8, 22);
      flipPath.quadraticBezierTo(2, 24, -4, 18);
      flipPath.quadraticBezierTo(-6, 6, 0, -12);
    }
    flipPath.close();
    canvas.drawPath(flipPath, Paint()..color = bodyColor);
    canvas.drawPath(flipPath, Paint()..color = Colors.black.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = 1.8);
    canvas.restore();
  }

  void _drawPenguinEye(Canvas canvas, double x, double y, double blink, AlexMood mood, double anim) {
    final eyeH = (1 - blink) * 13 + 1.5;
    // Eye white
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 13, height: eyeH.clamp(2.0, 14.0)),
        Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 13, height: eyeH.clamp(2.0, 14.0)),
        Paint()..color = const Color(0xFF1C1C2E)..style = PaintingStyle.stroke..strokeWidth = 1.8);

    if (blink < 0.7) {
      // Pupil
      final pupilX = mood == AlexMood.thinking ? x + sin(anim * 2 * pi) * 3 : x;
      final pupilY = mood == AlexMood.sad ? y + 2 : y;
      canvas.drawCircle(Offset(pupilX, pupilY), 4.5, Paint()..color = const Color(0xFF0D0D1A));

      // Shine
      if (mood == AlexMood.happy) {
        _drawHeart(canvas, Offset(pupilX + 1, pupilY - 1.5), 3.0, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(Offset(pupilX + 1.5, pupilY - 1.5), 1.8, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(pupilX - 1, pupilY + 1), 1, Paint()..color = Colors.white.withValues(alpha: 0.6));
      }

      // Star sparkle for happy
      if (mood == AlexMood.happy) {
        canvas.drawCircle(Offset(x, y), 8,
            Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.3 + sin(anim * 2 * pi) * 0.2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      // Sad half-closed top eyelid effect
      if (mood == AlexMood.sad) {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y - 2), width: 14, height: 10),
            pi, pi, false, Paint()..color = const Color(0xFF1C1C2E)..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
      }
    }
  }

  void _drawBeak(Canvas canvas, double cx, double cy, AlexMood mood, double anim) {
    const beakColor = Color(0xFFFF9800);
    const beakDark = Color(0xFFE67E00);

    switch (mood) {
      case AlexMood.happy:
        // Open beak, smiling
        final topBeak = Path();
        topBeak.moveTo(cx - 10, cy);
        topBeak.quadraticBezierTo(cx, cy - 6, cx + 10, cy);
        topBeak.quadraticBezierTo(cx, cy + 2 + anim, cx - 10, cy);
        topBeak.close();
        canvas.drawPath(topBeak, Paint()..color = beakColor);
        canvas.drawPath(topBeak, Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.2);

        final bottomBeak = Path();
        bottomBeak.moveTo(cx - 8, cy + 1);
        bottomBeak.quadraticBezierTo(cx, cy + 6 + anim * 2, cx + 8, cy + 1);
        canvas.drawPath(bottomBeak, Paint()..color = beakDark);
        canvas.drawPath(bottomBeak, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1);
        // tongue
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + 4 + anim), width: 5, height: 3),
            Paint()..color = const Color(0xFFFF6B7F));
        break;

      case AlexMood.sad:
        // Droopy beak
        final beak = Path();
        beak.moveTo(cx - 9, cy);
        beak.quadraticBezierTo(cx, cy - 4, cx + 9, cy);
        beak.quadraticBezierTo(cx, cy + 3, cx - 9, cy);
        beak.close();
        canvas.drawPath(beak, Paint()..color = beakColor.withValues(alpha: 0.8));
        canvas.drawPath(beak, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        // Tear drops
        canvas.drawCircle(Offset(cx - 12, cy + 8 + anim * 6), 2.5,
            Paint()..color = const Color(0xFF87CEEB).withValues(alpha: (1 - anim).clamp(0, 1)));
        canvas.drawCircle(Offset(cx + 14, cy + 6 + anim * 8), 2,
            Paint()..color = const Color(0xFF87CEEB).withValues(alpha: (1 - anim * 1.2).clamp(0, 1)));
        break;

      case AlexMood.thinking:
        // Slightly off-center beak, wiggly
        final beak = Path();
        beak.moveTo(cx - 9, cy);
        beak.quadraticBezierTo(cx + sin(anim * 2 * pi) * 2, cy - 5, cx + 9, cy);
        beak.quadraticBezierTo(cx, cy + 3, cx - 9, cy);
        beak.close();
        canvas.drawPath(beak, Paint()..color = beakColor);
        canvas.drawPath(beak, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        break;

      case AlexMood.surprised:
        // Open round beak
        final beak = Path();
        beak.moveTo(cx - 10, cy - 1);
        beak.quadraticBezierTo(cx, cy - 7, cx + 10, cy - 1);
        beak.quadraticBezierTo(cx, cy + 1, cx - 10, cy - 1);
        beak.close();
        canvas.drawPath(beak, Paint()..color = beakColor);
        canvas.drawPath(beak, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        // Open mouth "O"
        canvas.drawCircle(Offset(cx, cy + 3), 4 + anim * 1.5, Paint()..color = const Color(0xFF1C1C2E));
        canvas.drawCircle(Offset(cx, cy + 3), 2.5 + anim, Paint()..color = Colors.white.withValues(alpha: 0.2));
        break;

      case AlexMood.idle:
        // Neutral closed beak
        final beak = Path();
        beak.moveTo(cx - 9, cy);
        beak.quadraticBezierTo(cx, cy - 5, cx + 9, cy);
        beak.quadraticBezierTo(cx, cy + 3, cx - 9, cy);
        beak.close();
        canvas.drawPath(beak, Paint()..color = beakColor);
        canvas.drawPath(beak, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.2);
        // Tiny smile line under beak
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy + 2), width: 10, height: 5),
            0.1, pi - 0.2, false, Paint()..color = const Color(0xFF1C1C2E).withValues(alpha: 0.5)..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
        break;
    }
  }

  void _drawBowTie(Canvas canvas, double cx, double cy, Color accentColor) {
    final leftTri = Path();
    leftTri.moveTo(cx, cy);
    leftTri.lineTo(cx - 10, cy - 5);
    leftTri.lineTo(cx - 10, cy + 5);
    leftTri.close();
    canvas.drawPath(leftTri, Paint()..color = accentColor);

    final rightTri = Path();
    rightTri.moveTo(cx, cy);
    rightTri.lineTo(cx + 10, cy - 5);
    rightTri.lineTo(cx + 10, cy + 5);
    rightTri.close();
    canvas.drawPath(rightTri, Paint()..color = accentColor);

    // Center knot
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = accentColor);
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = Colors.white.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final x = center.dx, y = center.dy;
    path.moveTo(x, y + size / 4);
    path.cubicTo(x + size, y - size / 2, x + size * 0.6, y - size, x, y - size / 6);
    path.cubicTo(x - size * 0.6, y - size, x - size, y - size / 2, x, y + size / 4);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(CartoonAlexPainter old) => true;
}

class AlexCharacter extends StatefulWidget {
  final AlexMood mood;
  final Color color;
  final double size;
  const AlexCharacter({super.key, required this.mood, required this.color, this.size = 140});

  @override
  State<AlexCharacter> createState() => _AlexCharacterState();
}

class _AlexCharacterState extends State<AlexCharacter> with TickerProviderStateMixin {
  late AnimationController _bobCtrl, _blinkCtrl, _armCtrl, _mouthCtrl;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _armCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..repeat(reverse: true);
    _mouthCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 1800 + Random().nextInt(2000)));
      if (!mounted) break;
      await _blinkCtrl.forward();
      await _blinkCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _bobCtrl.dispose(); _blinkCtrl.dispose(); _armCtrl.dispose(); _mouthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bobCtrl, _blinkCtrl, _armCtrl, _mouthCtrl]),
      builder: (_, _) => SizedBox(
        width: widget.size, height: widget.size,
        child: CustomPaint(
          painter: CartoonAlexPainter(
            bob: sin(_bobCtrl.value * pi),
            blink: _blinkCtrl.value,
            armWave: sin(_armCtrl.value * pi),
            mouthAnim: _mouthCtrl.value,
            mood: widget.mood,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

// ─── Floating Question Marks ──────────────────────────────────────────────
class FloatingQmarks extends StatefulWidget {
  const FloatingQmarks({super.key});
  @override
  State<FloatingQmarks> createState() => _FloatingQmarksState();
}

class _FloatingQmarksState extends State<FloatingQmarks> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => SizedBox(width: 160, height: 100,
        child: Stack(
          children: List.generate(4, (i) {
            final phase = (i / 4 + _ctrl.value) % 1.0;
            final y = -(phase * 80);
            final x = sin(phase * pi * 2 + i) * 25;
            final opacity = (phase < 0.7 ? phase / 0.7 : (1 - phase) / 0.3).clamp(0.0, 1.0);
            return Positioned(
              left: 70 + x + (i - 2) * 18.0,
              top: 70 + y,
              child: Opacity(opacity: opacity,
                child: Text('?', style: TextStyle(fontSize: 16 + i * 4.0, fontWeight: FontWeight.w900,
                    color: Colors.white, shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1,1))]))),
            );
          }),
        )),
    );
  }
}

// ─── UI Helpers ───────────────────────────────────────────────────────────
class CartoonCard extends StatelessWidget {
  final Widget child;
  final Color bgColor;
  final Color borderColor;
  final EdgeInsets? padding;

  const CartoonCard({super.key, required this.child, required this.bgColor,
      required this.borderColor, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(color: borderColor.withValues(alpha: 0.4), blurRadius: 0, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class CartoonButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;
  final double fontSize;
  final IconData? icon;

  const CartoonButton({super.key, required this.label, required this.color,
      required this.shadowColor, required this.onTap, this.fontSize = 18, this.icon});

  @override
  State<CartoonButton> createState() => _CartoonButtonState();
}

class _CartoonButtonState extends State<CartoonButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            boxShadow: _pressed ? [] : [
              BoxShadow(color: widget.shadowColor, blurRadius: 0, offset: const Offset(0, 5)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: widget.fontSize + 2),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1,
                shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))])),
          ]),
        ),
      ),
    );
  }
}

// ─── Game Screen ──────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int _levelIdx = 2;
  int _playerNum = 0;
  int _compNum = 0;
  GamePhase _phase = GamePhase.entry;
  AlexMood _mood = AlexMood.idle;
  bool _confetti = false;
  Timer? _rollTimer;

  int _wins = 0, _losses = 0, _total = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _bgCtrl, _revealCtrl, _levelUpCtrl, _shakeCtrl, _bounceCtrl;
  late Animation<double> _revealAnim, _levelUpAnim, _shakeAnim, _bounceAnim;

  LevelConfig get _lvl => levels[_levelIdx];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut);
    _levelUpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _levelUpAnim = CurvedAnimation(parent: _levelUpCtrl, curve: Curves.elasticOut);
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: -1, end: 1).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    _bgCtrl.dispose(); _revealCtrl.dispose(); _levelUpCtrl.dispose();
    _shakeCtrl.dispose(); _bounceCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    _playSound('start.mp3');
    setState(() { _phase = GamePhase.rolling; _mood = AlexMood.thinking; });
    int ticks = 0;
    _rollTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() => _compNum = Random().nextInt(_lvl.maxNumber + 1));
      ticks++;
      if (ticks >= 25) {
        timer.cancel();
        final fin = Random().nextInt(_lvl.maxNumber + 1);
        final isWin = fin == _playerNum;
        final diff = (fin - _playerNum).abs();
        final isClose = !isWin && diff <= _lvl.closeThreshold;
        setState(() {
          _compNum = fin; _phase = GamePhase.result; _total++;
          if (isWin) { _wins++; _mood = AlexMood.happy; _confetti = true; }
          else if (isClose) { _losses++; _mood = AlexMood.surprised; }
          else { _losses++; _mood = AlexMood.sad; _shakeCtrl.forward(from: 0); }
        });
        // play result sound
        if (isWin) {
          _playSound('win.mp3');
        } else if (isClose) _playSound('close.mp3');
        else _playSound('lose.mp3');
        _revealCtrl.forward(from: 0);
      }
    });
  }

  void _playSound(String fileName) async {
    try {
      fileName = fileName.replaceAll('.mp3', '.wav');
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // ignore audio errors in environments without sound
    }
  }

  void _handleLevelUp() {
    setState(() => _confetti = false);
    if (_levelIdx < levels.length - 1) {
      setState(() => _phase = GamePhase.levelUp);
      _levelUpCtrl.forward(from: 0);
    } else {
      setState(() { _phase = GamePhase.champion; _confetti = true; });
      _levelUpCtrl.forward(from: 0);
    }
  }

  void _nextLevel() => setState(() {
    _levelIdx++; _playerNum = 0; _phase = GamePhase.picking; _mood = AlexMood.idle; _confetti = false;
  });

  void _playAgain() => setState(() {
    _playerNum = 0; _phase = GamePhase.picking; _mood = AlexMood.idle; _confetti = false;
  });

  void _resetAll() => setState(() {
    _levelIdx = 0; _playerNum = 0; _wins = 0; _losses = 0; _total = 0;
    _phase = GamePhase.picking; _mood = AlexMood.idle; _confetti = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Image Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/penguin_face.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay to make UI readable
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          ConfettiOverlay(active: _confetti),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                    child: _buildPhase(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Game title
          Expanded(
            child: CartoonCard(
              bgColor: Colors.white.withValues(alpha: 0.2),
              borderColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Text(_lvl.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LEVEL ${_lvl.level}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 2, shadows: [Shadow(color: Colors.black26, blurRadius: 2)])),
                  Text(_lvl.label, style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 2)),
                ]),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          // Level dots
          CartoonCard(
            bgColor: Colors.white.withValues(alpha: 0.2),
            borderColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(levels.length, (i) {
                final isActive = i == _levelIdx;
                final isDone = i < _levelIdx;
                return GestureDetector(
                  onTap: () => setState(() { _levelIdx = i; _playerNum = 0; _phase = GamePhase.picking; _mood = AlexMood.idle; _confetti = false; }),
                  child: Tooltip(
                    message: '${levels[i].emoji} Level ${levels[i].level}: ${levels[i].label}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 26 : 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFFFFD700) : isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isActive ? [const BoxShadow(color: Colors.white, blurRadius: 8)] : [],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          // Score
          CartoonCard(
            bgColor: const Color(0xFFFFD700),
            borderColor: const Color(0xFFFFA500),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('$_wins', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2)])),
              Text('/$_total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7))),
            ]),
          ),
          const SizedBox(width: 10),
          CartoonCard(
            bgColor: Colors.white.withValues(alpha: 0.12),
            borderColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('❤️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${_lvl.lives}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2)])),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case GamePhase.entry:    return _entryScreen();
      case GamePhase.picking:  return _pickScreen();
      case GamePhase.rolling:  return _rollScreen();
      case GamePhase.result:   return _resultScreen();
      case GamePhase.levelUp:  return _levelUpScreen();
      case GamePhase.champion: return _champScreen();
    }
  }

  // ── Entry / Level Select Screen ───────────────────────────────────────
  Widget _entryScreen() {
    return SingleChildScrollView(
      key: const ValueKey('entry'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 24),
            const Text('Choose a Level', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Pick any difficulty to start', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 20),
            for (var i = 0; i < levels.length; i++) ...[
              CartoonCard(
                bgColor: Colors.white,
                borderColor: levels[i].accent,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(backgroundColor: levels[i].bgTop, child: Text(levels[i].emoji, style: const TextStyle(fontSize: 20))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Level ${levels[i].level} · ${levels[i].label}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: levels[i].bgTop)),
                    const SizedBox(height: 6),
                    Text('Range: 0 – ${levels[i].maxNumber}   |   Close: ±${levels[i].closeThreshold}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text('Lives: ${levels[i].lives}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  CartoonButton(
                    label: 'START',
                    color: levels[i].bgTop,
                    shadowColor: levels[i].bgBottom,
                    icon: Icons.play_arrow_rounded,
                    onTap: () => setState(() { _levelIdx = i; _playerNum = 0; _phase = GamePhase.picking; _mood = AlexMood.idle; _confetti = false; }),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 20),
            GestureDetector(onTap: _resetAll, child: Text('Reset progress', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))))
          ]),
        ),
      ),
    );
  }

  // ── Pick Screen ───────────────────────────────────────────────────────
  Widget _pickScreen() {
    return SingleChildScrollView(
      key: const ValueKey('pick'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CartoonCard(
            bgColor: Colors.white,
            borderColor: _lvl.accent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AlexCharacter(mood: AlexMood.idle, color: _lvl.accent, size: 130),
              Text('Hiya! I\'m Penny! 🐧',
                  style: TextStyle(fontSize: 13, color: _lvl.accent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _lvl.bgTop.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _lvl.bgTop.withValues(alpha: 0.4)),
                ),
                child: Text('${_lvl.emoji} Level ${_lvl.level} · ${_lvl.label} · 0–${_lvl.maxNumber}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _lvl.bgTop, letterSpacing: 1)),
              ),
              const SizedBox(height: 20),
              const Text('Pick your number!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF333344))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _roundBtn(icon: Icons.remove_rounded, color: const Color(0xFFFF6B6B),
                    onTap: _playerNum > 0 ? () => setState(() => _playerNum--) : null),
                const SizedBox(width: 20),
                // Number display
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_lvl.bgTop, _lvl.bgBottom]),
                    shape: BoxShape.circle,
                    border: Border.all(color: _lvl.accent, width: 4),
                    boxShadow: [BoxShadow(color: _lvl.bgTop.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: Center(child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Text('$_playerNum', key: ValueKey(_playerNum),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
                  )),
                ),
                const SizedBox(width: 20),
                _roundBtn(icon: Icons.add_rounded, color: const Color(0xFF6CE563),
                    onTap: _playerNum < _lvl.maxNumber ? () => setState(() => _playerNum++) : null),
              ]),
              const SizedBox(height: 28),
              CartoonButton(
                label: 'GO!',
                color: _lvl.bgTop,
                shadowColor: _lvl.bgBottom,
                onTap: _startGame,
                fontSize: 22,
                icon: Icons.play_arrow_rounded,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: onTap == null ? color.withValues(alpha: 0.2) : color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: onTap == null ? [] : [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 0, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  // ── Roll Screen ───────────────────────────────────────────────────────
  Widget _rollScreen() {
    return Center(
      key: const ValueKey('roll'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(alignment: Alignment.center, children: [
          AlexCharacter(mood: AlexMood.thinking, color: _lvl.accent, size: 150),
          const Positioned(top: 0, right: 10, child: FloatingQmarks()),
        ]),
        const SizedBox(height: 16),
        CartoonCard(
          bgColor: Colors.white.withValues(alpha: 0.9),
          borderColor: _lvl.accent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Penny is rolling...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF333344))),
            Text('Your number: $_playerNum', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(height: 30),
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, _) => Transform.rotate(
            angle: _bgCtrl.value * 20 * pi,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_lvl.bgTop, _lvl.bgBottom]),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: [BoxShadow(color: _lvl.bgTop.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 8)],
              ),
              child: Transform.rotate(
                angle: -_bgCtrl.value * 20 * pi,
                child: Center(child: Text('$_compNum',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)]))),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Result Screen ─────────────────────────────────────────────────────
  Widget _resultScreen() {
    final isWin = _playerNum == _compNum;
    final diff = (_playerNum - _compNum).abs();
    final isClose = !isWin && diff <= _lvl.closeThreshold;

    final resultText = isWin ? 'MATCHED! 🎯' : isClose ? 'SO CLOSE! 🔥' : 'NOPE! ❌';
    final subtitle = isWin ? 'Perfect! You got it!' : isClose ? 'Only $diff away!' : '$diff apart. Try again!';
    final cardColor = isWin ? const Color(0xFF6CE563) : isClose ? const Color(0xFFFFCC00) : const Color(0xFFFF6B6B);
    final shadowColor = isWin ? const Color(0xFF3DA833) : isClose ? const Color(0xFFC89600) : const Color(0xFFC43030);

    return SingleChildScrollView(
      key: const ValueKey('result'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(isWin ? 0 : _shakeAnim.value * 6 * sin(_shakeCtrl.value * 12), 0),
              child: child,
            ),
            child: ScaleTransition(
              scale: _revealAnim,
              child: CartoonCard(
                bgColor: Colors.white,
                borderColor: cardColor,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Alex
                  AlexCharacter(mood: _mood, color: cardColor, size: 120),
                  const SizedBox(height: 8),
                  // Result banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: shadowColor, blurRadius: 0, offset: const Offset(0, 4))],
                    ),
                    child: Text(resultText, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 3)])),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  // YOU vs PENNY
                  Row(children: [
                    Expanded(child: _resultBubble('YOU', _playerNum, const Color(0xFF6C3FE8))),
                    Column(children: [
                      const SizedBox(height: 20),
                      Text('VS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.grey.shade300, letterSpacing: 2)),
                    ]),
                    Expanded(child: _resultBubble('PENNY', _compNum, const Color(0xFFFF6B6B))),
                  ]),
                  if (!isWin) ...[
                    const SizedBox(height: 16),
                    _diffBar(diff, _lvl.maxNumber, cardColor),
                  ],
                  const SizedBox(height: 20),
                  if (isWin) ...[
                    CartoonButton(
                      label: _levelIdx < levels.length - 1 ? 'NEXT LEVEL!' : 'CHAMPION!',
                      color: const Color(0xFF6CE563), shadowColor: const Color(0xFF3DA833),
                      icon: Icons.arrow_forward_rounded, onTap: _handleLevelUp,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(onTap: _playAgain,
                      child: Text('play this level again',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400,
                              decoration: TextDecoration.underline))),
                  ] else
                    CartoonButton(label: 'TRY AGAIN!', color: cardColor, shadowColor: shadowColor,
                        icon: Icons.refresh_rounded, onTap: _playAgain),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBubble(String label, int number, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 2)),
      const SizedBox(height: 8),
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)],
        ),
        child: Center(child: Text('$number',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color))),
      ),
    ]);
  }

  Widget _diffBar(int diff, int max, Color color) {
    final pct = (diff / max).clamp(0.0, 1.0);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('DISTANCE', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, letterSpacing: 2)),
        Text('$diff away', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(children: [
          Container(height: 10, color: Colors.grey.shade200),
          FractionallySizedBox(widthFactor: pct,
            child: Container(height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]))),
        ]),
      ),
    ]);
  }

  // ── Level Up Screen ───────────────────────────────────────────────────
  Widget _levelUpScreen() {
    final next = levels[_levelIdx + 1];
    return Center(
      key: const ValueKey('levelup'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ScaleTransition(
          scale: _levelUpAnim,
          child: CartoonCard(
            bgColor: Colors.white,
            borderColor: next.accent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AlexCharacter(mood: AlexMood.happy, color: next.accent, size: 140),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [next.bgTop, next.bgBottom]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: next.bgBottom.withValues(alpha: 0.5), blurRadius: 0, offset: const Offset(0, 4))],
                ),
                child: const Text('LEVEL UP! ⬆️',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
              ),
              const SizedBox(height: 16),
              CartoonCard(
                bgColor: next.bgTop.withValues(alpha: 0.08),
                borderColor: next.bgTop.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('${next.emoji} ${next.label}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: next.bgTop)),
                  const SizedBox(height: 4),
                  Text('Range: 0 – ${next.maxNumber}   |   Close: ±${next.closeThreshold}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
              const SizedBox(height: 20),
              CartoonButton(label: 'START LEVEL ${next.level}!',
                  color: next.bgTop, shadowColor: next.bgBottom,
                  icon: Icons.play_arrow_rounded, onTap: _nextLevel),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Champion Screen ───────────────────────────────────────────────────
  Widget _champScreen() {
    return Center(
      key: const ValueKey('champ'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ScaleTransition(
          scale: _levelUpAnim,
          child: CartoonCard(
            bgColor: Colors.white,
            borderColor: const Color(0xFFFFD700),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AlexCharacter(mood: AlexMood.happy, color: const Color(0xFFFFD700), size: 150),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0xFFCC7000), blurRadius: 0, offset: Offset(0, 4))],
                ),
                child: const Text('🏆 CHAMPION! 🏆',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
              ),
              const SizedBox(height: 12),
              const Text('You beat all 3 levels!',
                  style: TextStyle(fontSize: 14, color: Color(0xFF888899))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _statPill('⭐ WINS', '$_wins', const Color(0xFF6CE563)),
                _statPill('💀 LOSSES', '$_losses', const Color(0xFFFF6B6B)),
                _statPill('🎮 GAMES', '$_total', const Color(0xFF6C3FE8)),
              ]),
              const SizedBox(height: 20),
              CartoonButton(label: 'PLAY AGAIN!', color: const Color(0xFFFFD700),
                  shadowColor: const Color(0xFFCC7000), icon: Icons.replay_rounded, onTap: _resetAll),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, letterSpacing: 1)),
      ]),
    );
  }
}
