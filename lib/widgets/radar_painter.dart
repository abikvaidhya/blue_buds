import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_model.dart';
import '../theme/app_theme.dart';

class RadarPainter extends CustomPainter {
  final double sweepAngle; // 0..2π for the rotating beam
  final List<NearbyPeer> peers;
  final double pulse; // 0..1 for outer pulse

  RadarPainter({
    required this.sweepAngle,
    required this.peers,
    this.pulse = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 24;

    // Background glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.primary.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, bgPaint);

    // Concentric rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.primary.withOpacity(0.25);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxR * (i / 4), ringPaint);
    }

    // Outer pulse ring
    if (pulse > 0) {
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.primary.withOpacity(0.4 * (1 - pulse));
      canvas.drawCircle(center, maxR * (0.85 + 0.15 * pulse), pulsePaint);
    }

    // Cross lines
    final crossPaint = Paint()
      ..color = AppTheme.primary.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - maxR, center.dy),
      Offset(center.dx + maxR, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR),
      Offset(center.dx, center.dy + maxR),
      crossPaint,
    );

    // Sweeping beam (pie slice)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.6,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          AppTheme.primary.withOpacity(0.35),
          AppTheme.primary.withOpacity(0.05),
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, sweepPaint);

    // Center dot
    canvas.drawCircle(
      center,
      6,
      Paint()..color = AppTheme.primary,
    );
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.primary.withOpacity(0.5),
    );

    // Peer blips
    for (final peer in peers) {
      // Map RSSI to radius (stronger signal = closer to center)
      final t = ((peer.rssi + 100) / 60).clamp(0.15, 0.95);
      final r = maxR * (1.0 - t * 0.85);
      // Deterministic angle from id so it doesn't jump around
      final angle = (peer.id.hashCode % 360) * math.pi / 180;
      final pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );

      final color = peer.isSaved
          ? AppTheme.success
          : peer.isBlocked
              ? AppTheme.danger
              : AppTheme.primary;

      // Glow
      canvas.drawCircle(
        pos,
        14,
        Paint()..color = color.withOpacity(0.25),
      );
      // Dot
      canvas.drawCircle(pos, 6, Paint()..color = color);
      // Ring
      canvas.drawCircle(
        pos,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withOpacity(0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) {
    return old.sweepAngle != sweepAngle ||
        old.pulse != pulse ||
        old.peers.length != peers.length;
  }
}

class AnimatedRadar extends StatefulWidget {
  final List<NearbyPeer> peers;
  final bool isScanning;

  const AnimatedRadar({
    super.key,
    required this.peers,
    this.isScanning = true,
  });

  @override
  State<AnimatedRadar> createState() => _AnimatedRadarState();
}

class _AnimatedRadarState extends State<AnimatedRadar>
    with TickerProviderStateMixin {
  late final AnimationController _sweep;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sweep, _pulse]),
      builder: (context, _) {
        return CustomPaint(
          painter: RadarPainter(
            sweepAngle: widget.isScanning ? _sweep.value * 3 * math.pi : 0,
            peers: widget.peers,
            pulse: widget.isScanning ? _pulse.value : 1,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
