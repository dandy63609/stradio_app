import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/stradio_theme.dart';

/// Shape primitive matching the three SDF branches in `shaders/liquid_glass.frag`.
enum LiquidGlassShape { rounded, circle, pill }

/// Reusable optical refraction surface powered by `shaders/liquid_glass.frag`
/// (`docs/DESIGN.md` Component Spec, capped at 1 to 2 focal elements per screen).
///
/// Automatically falls back to a crisp matte `#FAF7F2` surface with `1px #DFD9CE`
/// border when reduced transparency / high contrast is active, or to frosted blur
/// if the active graphics backend does not support `ImageFilter.shader`.
class LiquidGlassLens extends StatefulWidget {
  const LiquidGlassLens({
    super.key,
    required this.child,
    this.shape = LiquidGlassShape.rounded,
    this.borderRadius = StradioRadii.tray,
    this.padding = EdgeInsets.zero,
    this.edgeIntensity = 0.032,
    this.rimIntensity = 0.095,
    this.baseIntensity = 0.015,
    this.rippleEffect = 0.08,
    this.tintOpacity = 0.22,
    this.warp = true,
    this.width,
    this.height,
  });

  final Widget child;
  final LiquidGlassShape shape;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double edgeIntensity;
  final double rimIntensity;
  final double baseIntensity;
  final double rippleEffect;
  final double tintOpacity;
  final bool warp;
  final double? width;
  final double? height;

  static ui.FragmentProgram? _cachedProgram;
  static bool _loadAttempted = false;

  @override
  State<LiquidGlassLens> createState() => _LiquidGlassLensState();
}

class _LiquidGlassLensState extends State<LiquidGlassLens> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _program = LiquidGlassLens._cachedProgram;
    if (_program == null && !LiquidGlassLens._loadAttempted) {
      _loadProgram();
    }
  }

  Future<void> _loadProgram() async {
    LiquidGlassLens._loadAttempted = true;
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      LiquidGlassLens._cachedProgram = program;
      if (mounted) {
        setState(() => _program = program);
      }
    } on Object {
      // Headless tests or older backends gracefully fall back to blur/matte surface.
    }
  }

  double _resolvedRadius(Size size) => switch (widget.shape) {
    LiquidGlassShape.circle => size.shortestSide * 0.5,
    LiquidGlassShape.pill => size.height * 0.5,
    LiquidGlassShape.rounded => widget.borderRadius,
  };

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    final effectiveBorderRadius = switch (widget.shape) {
      LiquidGlassShape.circle ||
      LiquidGlassShape.pill => BorderRadius.circular(StradioRadii.full),
      LiquidGlassShape.rounded => BorderRadius.circular(widget.borderRadius),
    };

    if (highContrast) {
      return Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: StradioColors.surfaceCard,
          borderRadius: effectiveBorderRadius,
          border: Border.all(color: StradioColors.borderSubtle),
        ),
        child: widget.child,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.hasBoundedWidth && constraints.maxWidth > 0
              ? constraints.maxWidth
              : (widget.width ?? 240.0);
          final h = constraints.hasBoundedHeight && constraints.maxHeight > 0
              ? constraints.maxHeight
              : (widget.height ?? 120.0);
          final radius = _resolvedRadius(Size(w, h));

          ui.ImageFilter filter = ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12);
          final program = _program;
          if (program != null && ui.ImageFilter.isShaderFilterSupported) {
            try {
              final shader = program.fragmentShader();
              shader.setFloat(0, w);
              shader.setFloat(1, h);
              shader.setFloat(2, radius);
              shader.setFloat(3, widget.warp ? 1.0 : 0.0);
              shader.setFloat(4, widget.edgeIntensity);
              shader.setFloat(5, widget.rimIntensity);
              shader.setFloat(6, widget.baseIntensity);
              shader.setFloat(7, 0.15); // u_edgeDistance
              shader.setFloat(8, 0.80); // u_rimDistance
              shader.setFloat(9, 0.12); // u_baseDistance
              shader.setFloat(10, 0.045); // u_cornerBoost
              shader.setFloat(11, reducedMotion ? 0.0 : widget.rippleEffect);
              shader.setFloat(12, widget.tintOpacity);
              filter = ui.ImageFilter.shader(shader);
            } on Object {
              // Keep safe blur fallback if shader uniforms fail on any backend.
            }
          }

          return ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: BackdropFilter(
              filter: filter,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: StradioColors.surfaceGlass,
                  borderRadius: effectiveBorderRadius,
                  border: Border.all(
                    color: StradioColors.surfaceGlassRim,
                    width: 1.0,
                  ),
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
