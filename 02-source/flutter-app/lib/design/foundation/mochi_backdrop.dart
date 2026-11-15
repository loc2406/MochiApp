import 'package:flutter/material.dart';

import 'mochi_palette.dart';
import '../pastel/pastel_theme.dart';

/// How the app paints the page behind the content.
enum MochiBackdropKind { gradient, solid, image }

/// Persisted background preset, independent of the user's accent.
@immutable
class MochiBackdrop {
  final MochiBackdropKind kind;
  final ImageProvider? image;
  final double scrim;
  final double blobs;
  final String preset;

  const MochiBackdrop({
    this.kind = MochiBackdropKind.gradient,
    this.image,
    this.scrim = .55,
    this.blobs = 1,
    this.preset = 'lavender',
  }) : assert(scrim >= 0 && scrim <= 1);

  const MochiBackdrop.image(ImageProvider this.image, {this.scrim = .55})
    : kind = MochiBackdropKind.image,
      preset = 'lavender',
      blobs = 1;

  const MochiBackdrop.solid()
    : kind = MochiBackdropKind.solid,
      preset = 'lavender',
      image = null,
      scrim = .55,
      blobs = 0;

  MochiBackdrop copyWith({
    MochiBackdropKind? kind,
    ImageProvider? image,
    double? scrim,
    double? blobs,
    String? preset,
  }) => MochiBackdrop(
    kind: kind ?? this.kind,
    image: image ?? this.image,
    scrim: scrim ?? this.scrim,
    blobs: blobs ?? this.blobs,
    preset: preset ?? this.preset,
  );

  @override
  bool operator ==(Object other) =>
      other is MochiBackdrop &&
      other.kind == kind &&
      other.image == image &&
      other.scrim == scrim &&
      other.blobs == blobs &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(kind, image, scrim, blobs, preset);
}

/// Accessibility and background preferences carried by the theme. Screens and
/// components read it instead of poking at the profile model.
@immutable
class MochiVisuals extends ThemeExtension<MochiVisuals> {
  final bool highContrast;
  final bool reduceMotion;
  final bool haptics;
  final MochiBackdrop backdrop;

  const MochiVisuals({
    this.highContrast = false,
    this.reduceMotion = false,
    this.haptics = true,
    this.backdrop = const MochiBackdrop(),
  });

  static MochiVisuals of(BuildContext context) =>
      Theme.of(context).extension<MochiVisuals>() ?? const MochiVisuals();

  @override
  MochiVisuals copyWith({
    bool? highContrast,
    bool? reduceMotion,
    bool? haptics,
    MochiBackdrop? backdrop,
  }) => MochiVisuals(
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    haptics: haptics ?? this.haptics,
    backdrop: backdrop ?? this.backdrop,
  );

  @override
  MochiVisuals lerp(covariant MochiVisuals? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// Paints the accent-derived gradient plus two soft blobs, or a wallpaper with
/// a readable scrim. No blur filters: blobs are radial gradients, which keeps
/// scrolling cheap on low-end phones.
class MochiBackground extends StatelessWidget {
  final Widget child;
  final MochiBackdrop? backdrop;
  const MochiBackground({super.key, required this.child, this.backdrop});

  @override
  Widget build(BuildContext context) {
    final palette = MochiPalette.of(context);
    final config = backdrop ?? MochiVisuals.of(context).backdrop;
    final showBlobs = config.blobs > 0 && !palette.highContrast;
    final colors = PastelBackgrounds.colors(config.preset, palette.isDark);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: config.kind == MochiBackdropKind.solid
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
            color: config.kind == MochiBackdropKind.solid ? colors.first : null,
          ),
        ),
        if (config.kind == MochiBackdropKind.image && config.image != null) ...[
          ExcludeSemantics(
            child: Image(
              image: config.image!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
          ColoredBox(color: colors.first.withValues(alpha: config.scrim)),
        ],
        if (showBlobs) ...[
          Positioned(
            top: -90,
            right: -70,
            child: _Blob(color: colors.last.withValues(alpha: .35), size: 280),
          ),
          Positioned(
            top: 210,
            left: -120,
            child: _Blob(color: colors.first.withValues(alpha: .25), size: 320),
          ),
          Positioned(
            bottom: -140,
            right: -60,
            child: _Blob(color: colors.last.withValues(alpha: .35), size: 260),
          ),
        ],
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
