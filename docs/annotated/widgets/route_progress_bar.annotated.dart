/// route_progress_bar.dart: Source file from lib/lib/widgets/route_progress_bar.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'package:flutter/material.dart';

/// A lightweight horizontal progress bar that animates as route progress
/// values (0..1) arrive. It tolerates null/NaN inputs by fading out.
class RouteProgressBar extends StatefulWidget {
  /// [Brief description of this field]
  final Stream<double?> progressStream;
  /// [Brief description of this field]
  final double height;
  /// [Brief description of this field]
  final Duration animationDuration;
  /// [Brief description of this field]
  final Color backgroundColor;
  /// [Brief description of this field]
  final Color fillColor;
  /// [Brief description of this field]
  final BorderRadiusGeometry borderRadius;

  const RouteProgressBar({
    super.key,
    required this.progressStream,
    this.height = 6,
    this.animationDuration = const Duration(milliseconds: 250),
    this.backgroundColor = const Color(0x22000000),
    this.fillColor = const Color(0xFF1E88E5),
    /// all: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  /// createState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  State<RouteProgressBar> createState() => _RouteProgressBarState();
}

/// _RouteProgressBarState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _RouteProgressBarState extends State<RouteProgressBar> {
  double _progress = 0.0; // 0..1
  /// [Brief description of this field]
  late final Stream<double?> _stream;
  @override
  /// initState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void initState() {
    /// initState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    super.initState();
    _stream = widget.progressStream;
    /// listen: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _stream.listen((v) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!mounted) return;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (v == null || v.isNaN) return; // ignore invalid
      /// clamp: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final clamped = v.clamp(0.0, 1.0);
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if ((clamped - _progress).abs() > 0.0005) {
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() => _progress = clamped);
      }
    });
  }

  @override
  /// build: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        /// of: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final barWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        return Semantics(
          container: true,
          explicitChildNodes: false,
          label: 'Route progress',
          /// toStringAsFixed: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
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
