import 'package:flutter/material.dart';

/// Stable accent colour derived from a title (used for music "album art").
Color accentFor(String seed) {
  final hue = (seed.hashCode.abs() % 360).toDouble();
  return HSVColor.fromAHSV(1, hue, 0.62, 0.95).toColor();
}

/// Generated gradient cover with a music note. Also used (blurred + scaled)
/// as the reflective background on the audio screen.
class ArtBox extends StatelessWidget {
  const ArtBox({
    super.key,
    required this.seed,
    this.radius = 18,
    this.iconSize = 32,
  });

  final String seed;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = accentFor(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, Color.lerp(c, Colors.black, 0.5)!],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
