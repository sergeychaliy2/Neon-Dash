library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../render/palette.dart';

abstract final class NeonMetrics {
  static const double corner = 18.0;
  static const double buttonCorner = 14.0;
  static const double hairline = 1.4;
  static const double panelPadding = 22.0;
  static const double rowGap = 12.0;

  static const double tracking = 2.4;
}

class RiseIn extends StatefulWidget {
  const RiseIn({
    required this.child,
    this.index = 0,
    this.lift = 14.0,
    super.key,
  });

  final Widget child;

  final int index;

  final double lift;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  static const Duration _travel = Duration(milliseconds: 260);
  static const Duration _step = Duration(milliseconds: 45);
  static const int _maxStaggered = 9;

  late final AnimationController _controller;
  late final Animation<double> _eased;

  @override
  void initState() {
    super.initState();

    final place = widget.index.clamp(0, _maxStaggered);
    final delay = _step * place;
    final total = delay + _travel;

    _controller = AnimationController(vsync: this, duration: total);
    _eased = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        total.inMicroseconds == 0
            ? 0.0
            : delay.inMicroseconds / total.inMicroseconds,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _eased,
        builder: (context, child) => Opacity(
          opacity: _eased.value,
          child: Transform.translate(
            offset: Offset(0.0, (1.0 - _eased.value) * widget.lift),
            child: child,
          ),
        ),
        child: widget.child,
      );
}

class ScreenSwitch extends StatelessWidget {
  const ScreenSwitch({
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: <Widget>[...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(NeonMetrics.panelPadding),
    this.corner = NeonMetrics.corner,
    this.tint,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double corner;

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final edge = tint ?? Palette.glassEdge;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(corner),
        border: Border.all(
          color: edge.withValues(alpha: edge.a * 0.8),
          width: NeonMetrics.hairline,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Palette.glassSheen,
            Palette.glassFill,
            Palette.panelFloor,
          ],
          stops: <double>[0.0, 0.34, 1.0],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class NeonLabel extends StatelessWidget {
  const NeonLabel(
    this.text, {
    this.size = 16.0,
    this.color = Palette.hudPrimary,
    this.weight = FontWeight.w600,
    this.tracking = NeonMetrics.tracking,
    this.glow = 1.0,
    this.align = TextAlign.center,
    this.maxLines,
    super.key,
  });

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final double tracking;

  final double glow;
  final TextAlign align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: 1.15,
          shadows: glow <= 0.0
              ? null
              : <Shadow>[
                  Shadow(
                    color: color.withValues(alpha: 0.55 * glow),
                    blurRadius: size * 0.55,
                  ),
                  Shadow(
                    color: color.withValues(alpha: 0.25 * glow),
                    blurRadius: size * 1.4,
                  ),
                ],
        ),
      );
}

class NeonButton extends StatefulWidget {
  const NeonButton({
    required this.label,
    required this.onPressed,
    this.hue,
    this.emphasis = ButtonEmphasis.normal,
    this.enabled = true,
    this.note,
    super.key,
  });

  final String label;

  final VoidCallback? onPressed;

  final double? hue;

  final ButtonEmphasis emphasis;
  final bool enabled;

  final String? note;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

enum ButtonEmphasis {
  primary,

  normal,

  quiet,
}

class _NeonButtonState extends State<NeonButton> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _live => widget.enabled && widget.onPressed != null;

  void _setPressed({required bool value}) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered({required bool value}) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final hue = widget.hue ?? Palette.craftHue;
    final base = colorFromHsl(hue, 0.9, 0.62);

    final double lift;
    if (!_live) {
      lift = 0.22;
    } else if (_pressed) {
      lift = 1.0;
    } else if (_hovered) {
      lift = 0.78;
    } else {
      lift = switch (widget.emphasis) {
        ButtonEmphasis.primary => 0.6,
        ButtonEmphasis.normal => 0.42,
        ButtonEmphasis.quiet => 0.28,
      };
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NeonLabel(
          widget.label,
          size: widget.emphasis == ButtonEmphasis.primary ? 17.0 : 15.0,
          color: _live
              ? Color.lerp(Palette.hudPrimary, base, 0.35)!
              : Palette.hudDim,
          glow: _live ? lift : 0.0,
          weight: FontWeight.w700,
        ),
        if (widget.note != null) ...<Widget>[
          const SizedBox(height: 4.0),
          NeonLabel(
            widget.note!,
            size: 11.0,
            color: Palette.hudDim,
            glow: 0.0,
            tracking: 1.4,
            weight: FontWeight.w500,
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: _live ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovered(value: true),
      onExit: (_) => _setHovered(value: false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _live ? (_) => _setPressed(value: true) : null,
        onTapUp: _live ? (_) => _setPressed(value: false) : null,
        onTapCancel: _live ? () => _setPressed(value: false) : null,
        onTap: _live ? () => widget.onPressed?.call() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: 22.0,
            vertical: _pressed ? 12.0 : 13.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeonMetrics.buttonCorner),
            color: base.withValues(alpha: 0.06 + 0.12 * lift),
            border: Border.all(
              color: base.withValues(alpha: 0.2 + 0.7 * lift),
              width: NeonMetrics.hairline,
            ),
            boxShadow: _live
                ? <BoxShadow>[
                    BoxShadow(
                      color: base.withValues(alpha: 0.22 * lift),
                      blurRadius: 18.0 * lift,
                      spreadRadius: 1.0,
                    ),
                  ]
                : null,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class NeonSlider extends StatefulWidget {
  const NeonSlider({
    required this.value,
    required this.onChanged,
    this.hue,
    super.key,
  });

  final double value;

  final ValueChanged<double> onChanged;

  final double? hue;

  @override
  State<NeonSlider> createState() => _NeonSliderState();
}

class _NeonSliderState extends State<NeonSlider> {
  static const double _height = 30.0;
  static const double _trackHeight = 5.0;
  static const double _handleRadius = 8.0;

  bool _dragging = false;

  void _report(Offset local, double width) {
    if (width <= 0.0) return;
    final span = width - _handleRadius * 2.0;
    final along = (local.dx - _handleRadius) / (span <= 0.0 ? width : span);
    widget.onChanged(along.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final hue = widget.hue ?? Palette.craftHue;
    final accent = colorFromHsl(hue, 0.9, 0.62);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              setState(() => _dragging = true);
              _report(details.localPosition, width);
            },
            onTapUp: (_) => setState(() => _dragging = false),
            onTapCancel: () => setState(() => _dragging = false),
            onHorizontalDragStart: (details) {
              setState(() => _dragging = true);
              _report(details.localPosition, width);
            },
            onHorizontalDragUpdate: (details) =>
                _report(details.localPosition, width),
            onHorizontalDragEnd: (_) => setState(() => _dragging = false),
            onHorizontalDragCancel: () => setState(() => _dragging = false),
            child: CustomPaint(
              size: Size(width, _height),
              painter: _SliderPainter(
                value: widget.value,
                accent: accent,
                held: _dragging,
                trackHeight: _trackHeight,
                handleRadius: _handleRadius,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.value,
    required this.accent,
    required this.held,
    required this.trackHeight,
    required this.handleRadius,
  });

  final double value;
  final Color accent;
  final bool held;
  final double trackHeight;
  final double handleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final middle = size.height * 0.5;
    final span = size.width - handleRadius * 2.0;
    final at = handleRadius + span * value.clamp(0.0, 1.0);

    final track = Rect.fromLTRB(
      handleRadius,
      middle - trackHeight * 0.5,
      size.width - handleRadius,
      middle + trackHeight * 0.5,
    );
    final corner = Radius.circular(trackHeight * 0.5);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(track, corner),
        paint..color = Palette.routeTrack,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(track.left, track.top, at, track.bottom),
          corner,
        ),
        paint..color = accent.withValues(alpha: held ? 1.0 : 0.8),
      )
      ..drawCircle(
        Offset(at, middle),
        handleRadius * (held ? 1.9 : 1.5),
        paint..color = accent.withValues(alpha: held ? 0.3 : 0.16),
      )
      ..drawCircle(
        Offset(at, middle),
        handleRadius,
        paint..color = accent,
      );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.held != held ||
      oldDelegate.accent != accent;
}

class NeonToggle extends StatelessWidget {
  const NeonToggle({
    required this.value,
    required this.onChanged,
    this.hue,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double? hue;

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHsl(hue ?? Palette.craftHue, 0.9, 0.62);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 54.0,
          height: 28.0,
          padding: const EdgeInsets.all(3.0),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            color: accent.withValues(alpha: value ? 0.22 : 0.06),
            border: Border.all(
              color: accent.withValues(alpha: value ? 0.9 : 0.3),
              width: NeonMetrics.hairline,
            ),
          ),
          child: Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accent : Palette.hudDim,
              boxShadow: value
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 10.0,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.label,
    required this.detail,
    required this.control,
    super.key,
  });

  final String label;
  final String detail;
  final Widget control;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            NeonLabel(
              label,
              size: 12.0,
              color: Palette.hudPrimary,
              glow: 0.4,
              tracking: 2.2,
              weight: FontWeight.w700,
              align: TextAlign.left,
            ),
            const SizedBox(height: 4.0),
            NeonLabel(
              detail,
              size: 10.0,
              color: Palette.hudDim,
              glow: 0.0,
              tracking: 1.0,
              weight: FontWeight.w500,
              align: TextAlign.left,
              maxLines: 2,
            ),
            const SizedBox(height: 10.0),
            control,
          ],
        ),
      );
}

class NeonTabBar extends StatelessWidget {
  const NeonTabBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < labels.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6.0),
            _NeonTab(
              label: labels[i],
              active: i == selected,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      );
}

class _NeonTab extends StatefulWidget {
  const _NeonTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NeonTab> createState() => _NeonTabState();
}

class _NeonTabState extends State<_NeonTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final glow = active ? 1.0 : (_hovered ? 0.5 : 0.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 9.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NeonMetrics.buttonCorner),
            color: Palette.glassFill.withValues(
              alpha: Palette.glassFill.a * (active ? 2.2 : 0.8),
            ),
            border: Border(
              bottom: BorderSide(
                color: Palette.hudPrimary.withValues(alpha: 0.1 + 0.8 * glow),
                width: active ? 2.2 : 1.0,
              ),
            ),
          ),
          child: NeonLabel(
            widget.label,
            size: 13.0,
            color: active ? Palette.hudPrimary : Palette.hudDim,
            glow: glow,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class StatLine extends StatelessWidget {
  const StatLine({
    required this.label,
    required this.value,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Row(
          children: <Widget>[
            NeonLabel(
              label,
              size: 12.0,
              color: Palette.hudDim,
              glow: 0.0,
              tracking: 1.8,
              weight: FontWeight.w500,
            ),
            const Expanded(child: _Leader()),
            NeonLabel(
              value,
              size: 15.0,
              color: accent ?? Palette.hudPrimary,
              glow: 0.6,
              weight: FontWeight.w700,
            ),
          ],
        ),
      );
}

class _Leader extends StatelessWidget {
  const _Leader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: CustomPaint(
          size: const Size(double.infinity, 1.0),
          painter: _LeaderPainter(),
        ),
      );
}

class _LeaderPainter extends CustomPainter {
  static const double _step = 6.0;
  static const double _radius = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Palette.hudDim.withValues(alpha: 0.28);
    final count = math.max(0, (size.width / _step).floor());
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(i * _step + _step * 0.5, size.height * 0.5),
        _radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter oldDelegate) => false;
}
