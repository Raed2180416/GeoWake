import 'package:flutter/material.dart';

/// A lightweight horizontal progress bar that animates as route progress
/// values (0..1) arrive. It tolerates null/NaN inputs by fading out.
class RouteProgressBar extends StatefulWidget {
  final Stream<double?> progressStream;
  final double height;
  final Duration animationDuration;
  final Color backgroundColor;
  final Color fillColor;
  final BorderRadiusGeometry borderRadius;

  const RouteProgressBar({
    super.key,
    required this.progressStream,
    this.height = 6,
    this.animationDuration = const Duration(milliseconds: 250),
    this.backgroundColor = const Color(0x22000000),
    this.fillColor = const Color(0xFF1E88E5),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  State<RouteProgressBar> createState() => _RouteProgressBarState();
}

class _RouteProgressBarState extends State<RouteProgressBar> {
  double _progress = 0.0; // 0..1
  late final Stream<double?> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.progressStream;
    _stream.listen((v) {
      if (!mounted) return;
      if (v == null || v.isNaN) return; // ignore invalid
      final clamped = v.clamp(0.0, 1.0);
      if ((clamped - _progress).abs() > 0.0005) {
        setState(() => _progress = clamped);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        return Semantics(
          container: true,
          explicitChildNodes: false,
          label: 'Route progress',
          value: '${(_progress * 100).toStringAsFixed(0)}%',
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: widget.borderRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                width: barWidth * _progress,
                decoration: BoxDecoration(
                  color: widget.fillColor,
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
