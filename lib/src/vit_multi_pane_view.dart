import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'vit_multi_pane_controller.dart';
import 'vit_multi_pane_page.dart';

/// Renders pages from a [VitMultiPaneController] side by side.
///
/// The package is deliberately IGNORANT of any responsive rule (e.g. "one
/// page on narrow screens, several when there is room"): the user decides
/// how many and which pages are visible via [visibleIndices], which receives
/// the available constraints and returns the indices to show. The panes are
/// separated by a draggable divider; when a page is a [VitMultiPanePage],
/// its [VitMultiPanePage.minWidth] / [VitMultiPanePage.maxWidth] clamp the
/// divider position.
class VitMultiPaneView extends StatefulWidget {
  const VitMultiPaneView({
    super.key,
    required this.controller,
    required this.visibleIndices,
    this.dividerWidth = 4,
    this.dividerColor = const Color(0xFFE0E0E0),
    this.dividerBuilder,
  });

  /// The controller holding the pages. Required.
  final VitMultiPaneController controller;

  /// Decides which page indices are visible for the current constraints.
  ///
  /// Example — one page below 600px, two pages (0 and 1) above:
  /// ```dart
  /// visibleIndices: (c) => c.maxWidth < 600 ? [0] : [0, 1],
  /// ```
  final List<int> Function(BoxConstraints constraints) visibleIndices;

  /// Thickness of each draggable divider, in logical pixels.
  final double dividerWidth;

  /// Color of each draggable divider (ignored when [dividerBuilder] is set).
  final Color dividerColor;

  /// Optional builder for the divider's visual.
  ///
  /// When null, a plain [Container] with [dividerColor] is used. When
  /// provided, the returned widget is placed in a box of [dividerWidth] ×
  /// full height and wrapped in the drag gesture — the drag behavior stays
  /// in the package, the look is fully yours (color, icon, handle, …).
  final Widget Function(BuildContext context, int dividerIndex)?
      dividerBuilder;

  @override
  State<VitMultiPaneView> createState() => _VitMultiPaneViewState();
}

class _VitMultiPaneViewState extends State<VitMultiPaneView> {
  /// Fraction of the panes area occupied by each visible pane. Always sums
  /// to 1 while dragging; may sum below 1 (slack absorbed by the trailing
  /// [Spacer]) when min/max constraints can't be satisfied exactly.
  List<double> _fractions = const [];

  /// Valid visible indices from the last build.
  List<int> _visibleIndices = const [];

  // Active drag state. The drag is start-based (absolute pointer position),
  // so the divider follows the pointer exactly and never jumps when grabbed.
  int? _activeDivider;
  double _dragStartLeftTotal = 0;
  double _dragStartX = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant VitMultiPaneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _activeDivider = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  double _panesWidth(BoxConstraints constraints, int paneCount) {
    final dividerTotal = widget.dividerWidth * math.max(0, paneCount - 1);
    return constraints.maxWidth - dividerTotal;
  }

  /// Ensures [_fractions] matches [count] and, when there is room, lays out
  /// panes within their min/max — so the initial layout is never in a state
  /// a drag would snap out of. When the minimums can't fit, keeps the
  /// (shrunk) layout and lets the drag move freely.
  void _syncFractions(int count, double panesWidth) {
    if (_fractions.length != count) {
      _fractions = List<double>.filled(count, 1 / count);
    }
    if (panesWidth <= 0) return;

    final minF = List<double>.generate(count, (i) {
      final w = VitMultiPanePage.minWidthOf(
        widget.controller.pageAt(_visibleIndices[i]),
      );
      return w == null ? 0.0 : w / panesWidth;
    });
    final maxF = List<double>.generate(count, (i) {
      final w = VitMultiPanePage.maxWidthOf(
        widget.controller.pageAt(_visibleIndices[i]),
      );
      return w == null ? 1.0 : w / panesWidth;
    });

    // Impossible layout: keep the current (shrunk) fractions, the drag
    // handles it smoothly.
    if (minF.fold<double>(0, (a, b) => a + b) > 1.0) return;

    var adjusted = List<double>.of(_fractions);
    for (var i = 0; i < count; i++) {
      final lo = minF[i];
      final hi = math.max(maxF[i], lo);
      adjusted[i] = adjusted[i].clamp(lo, hi).toDouble();
    }
    // If clamping overflowed, trim panes that are above their minimum
    // proportionally until the layout fits (guaranteed to terminate:
    // each pass removes exactly the excess).
    var sum = adjusted.fold<double>(0, (a, b) => a + b);
    while (sum > 1.0 + 1e-9) {
      var capacity = 0.0;
      for (var i = 0; i < count; i++) {
        capacity += adjusted[i] - minF[i];
      }
      if (capacity <= 1e-9) return;
      final excess = sum - 1.0;
      for (var i = 0; i < count; i++) {
        final above = adjusted[i] - minF[i];
        if (above > 0) adjusted[i] -= excess * above / capacity;
      }
      sum = adjusted.fold<double>(0, (a, b) => a + b);
    }
    _fractions = adjusted;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _visibleIndices = widget
            .visibleIndices(constraints)
            .where((i) => i >= 0 && i < widget.controller.length)
            .toList();
        final paneCount = _visibleIndices.length;
        if (paneCount == 0) return const SizedBox.shrink();

        final panesWidth = _panesWidth(constraints, paneCount);
        if (panesWidth <= 0) return const SizedBox.shrink();
        _syncFractions(paneCount, panesWidth);

        final children = <Widget>[];
        for (var i = 0; i < paneCount; i++) {
          if (i > 0) children.add(_buildDivider(i - 1, panesWidth));
          children.add(_buildPane(i, panesWidth));
        }
        // Absorbs any slack when the pages' widths don't fill the row.
        children.add(const Spacer());
        return Row(children: children);
      },
    );
  }

  Widget _buildPane(int visibleIndex, double panesWidth) {
    final fraction = _fractions[visibleIndex];
    return SizedBox(
      width: fraction * panesWidth,
      child: widget.controller.pageAt(_visibleIndices[visibleIndex]),
    );
  }

  Widget _buildDivider(int dividerIndex, double panesWidth) {
    final builder = widget.dividerBuilder;
    final Widget child;
    if (builder != null) {
      child = builder(context, dividerIndex);
    } else {
      child = Container(color: widget.dividerColor);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) =>
          _handleDragStart(dividerIndex, details.globalPosition.dx),
      onHorizontalDragUpdate: (details) =>
          _handleDragUpdate(panesWidth, details.globalPosition.dx),
      onHorizontalDragEnd: (_) => _handleDragEnd(),
      onHorizontalDragCancel: _handleDragEnd,
      // Fixed slot (dividerWidth × full height) keeps the layout math
      // stable regardless of what the builder paints inside.
      child: SizedBox(
        width: widget.dividerWidth,
        height: double.infinity,
        child: child,
      ),
    );
  }

  double _sumFractions(int from, int to) {
    var sum = 0.0;
    for (var i = from; i <= to; i++) {
      sum += _fractions[i];
    }
    return sum;
  }

  /// Valid range for the divider's left-total fraction, given the min/max
  /// widths of EVERY pane on each side (not just the adjacent ones): the
  /// divider can't push the left group below their combined minimums nor
  /// above their combined maximums. Conflicting constraints degrade to
  /// (0, 1) — free drag.
  ({double lower, double upper}) _dividerBounds(
    int dividerIndex,
    double panesWidth,
  ) {
    var leftMin = 0.0;
    var leftMax = 0.0;
    for (var i = 0; i <= dividerIndex; i++) {
      final page = widget.controller.pageAt(_visibleIndices[i]);
      leftMin += (VitMultiPanePage.minWidthOf(page) ?? 0) / panesWidth;
      leftMax +=
          (VitMultiPanePage.maxWidthOf(page) ?? double.infinity) / panesWidth;
    }
    var rightMin = 0.0;
    var rightMax = 0.0;
    for (var i = dividerIndex + 1; i < _fractions.length; i++) {
      final page = widget.controller.pageAt(_visibleIndices[i]);
      rightMin += (VitMultiPanePage.minWidthOf(page) ?? 0) / panesWidth;
      rightMax +=
          (VitMultiPanePage.maxWidthOf(page) ?? double.infinity) / panesWidth;
    }

    final lower = math.max(leftMin, 1 - rightMax);
    final upper = math.min(leftMax, 1 - rightMin);
    if (lower > upper || !lower.isFinite || !upper.isFinite) {
      return (lower: 0.0, upper: 1.0);
    }
    return (lower: lower, upper: upper);
  }

  void _handleDragStart(int dividerIndex, double globalX) {
    _activeDivider = dividerIndex;
    _dragStartLeftTotal = _sumFractions(0, dividerIndex);
    _dragStartX = globalX;
  }

  void _handleDragUpdate(double panesWidth, double globalX) {
    final dividerIndex = _activeDivider;
    if (dividerIndex == null || dividerIndex + 1 >= _fractions.length) return;
    if (panesWidth <= 0) return;

    final bounds = _dividerBounds(dividerIndex, panesWidth);
    final startValid = _dragStartLeftTotal >= bounds.lower &&
        _dragStartLeftTotal <= bounds.upper;

    var newLeftTotal = _dragStartLeftTotal + (globalX - _dragStartX) / panesWidth;
    if (startValid) {
      // Normal case: the divider stays inside its valid range.
      newLeftTotal = newLeftTotal.clamp(bounds.lower, bounds.upper).toDouble();
    } else if (_dragStartLeftTotal < bounds.lower) {
      // Layout can't fit the minimums: never snap to the boundary — cap at
      // the top so the divider can cross into the valid zone freely.
      newLeftTotal = math.min(newLeftTotal, bounds.upper);
    } else {
      // Mirror case: start above the valid range.
      newLeftTotal = math.max(newLeftTotal, bounds.lower);
    }

    final newRightTotal = 1.0 - newLeftTotal;
    if (newRightTotal <= 0) return;
    final leftTotal = _dragStartLeftTotal;
    final rightTotal = 1.0 - leftTotal;
    if (leftTotal <= 0 || rightTotal <= 0) return;

    setState(() {
      // Redistribute proportionally: every pane on each side of the divider
      // scales by the same factor, keeping the total at 1.
      final leftScale = newLeftTotal / leftTotal;
      for (var i = 0; i <= dividerIndex; i++) {
        _fractions[i] *= leftScale;
      }
      final rightScale = newRightTotal / rightTotal;
      for (var i = dividerIndex + 1; i < _fractions.length; i++) {
        _fractions[i] *= rightScale;
      }
    });
  }

  void _handleDragEnd() {
    _activeDivider = null;
  }
}
