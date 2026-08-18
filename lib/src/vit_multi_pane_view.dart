import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'vit_multi_pane_controller.dart';
import 'vit_multi_pane_page.dart';

/// Renders pages from a [VitMultiPaneController] side by side.
///
/// All pages in the controller are always visible. The panes are separated
/// by a draggable divider; when a page is a [VitMultiPanePage], its
/// [VitMultiPanePage.minWidth] / [VitMultiPanePage.maxWidth] clamp the
/// divider position.
class VitMultiPaneView extends StatefulWidget {
  const VitMultiPaneView({
    super.key,
    required this.controller,
    this.dividerWidth = 4,
    this.dividerHitWidth = 12,
    this.dividerColor = const Color(0xFFE0E0E0),
    this.dividerBuilder,
  })  : assert(dividerWidth >= 0),
        assert(dividerHitWidth >= 0);

  /// The controller holding the pages. Required.
  final VitMultiPaneController controller;

  /// Thickness of each divider's visual, in logical pixels.
  final double dividerWidth;

  /// Width of the invisible strip that grabs the divider, in logical pixels.
  ///
  /// A hairline divider is painfully hard to hit, so the drag area is a
  /// separate overlay, centered on the divider and at least
  /// [dividerWidth] wide. It takes no layout space (widening it does not
  /// move the panes) and it is translucent to hit-testing, so page content
  /// underneath still receives taps, hovers and its own gestures.
  final double dividerHitWidth;

  /// Color of each draggable divider (ignored when [dividerBuilder] is set).
  final Color dividerColor;

  /// Optional builder for the divider's visual.
  ///
  /// When null, a plain [Container] with [dividerColor] is used. When
  /// provided, the returned widget is placed in a box of [dividerWidth] ×
  /// full height — the drag behavior stays in the package (see
  /// [dividerHitWidth]), the look is fully yours (color, icon, handle, …).
  final Widget Function(BuildContext context, int dividerIndex)?
      dividerBuilder;

  @override
  State<VitMultiPaneView> createState() => _VitMultiPaneViewState();
}

/// Slack below which two widths are considered equal. Drag deltas arrive in
/// physical-pixel steps, so anything finer than this is noise.
const double _epsilon = 1e-6;

class _VitMultiPaneViewState extends State<VitMultiPaneView> {
  /// Fraction of the panes area occupied by each visible pane. Always sums
  /// to 1 while dragging; may sum below 1 (slack absorbed by the trailing
  /// [Spacer]) when min/max constraints can't be satisfied exactly.
  List<double> _fractions = const [];

  // Active drag state. Every update is recomputed from the layout snapshotted
  // at drag start against the absolute pointer position, so the divider sits
  // exactly under the pointer and no error can accumulate over the (dozens
  // of) update events a single drag produces.
  int? _activeDivider;
  List<double> _dragStartFractions = const [];
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
      _handleDragEnd();
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
      final w = VitMultiPanePage.minWidthOf(widget.controller.pageAt(i));
      return w == null ? 0.0 : w / panesWidth;
    });
    final maxF = List<double>.generate(count, (i) {
      final w = VitMultiPanePage.maxWidthOf(widget.controller.pageAt(i));
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
        final paneCount = widget.controller.length;
        if (paneCount == 0) return const SizedBox.shrink();

        final panesWidth = _panesWidth(constraints, paneCount);
        if (panesWidth <= 0) return const SizedBox.shrink();
        _syncFractions(paneCount, panesWidth);

        final widths = List<double>.generate(
          paneCount,
          (i) => _fractions[i] * panesWidth,
        );

        final row = <Widget>[];
        for (var i = 0; i < paneCount; i++) {
          if (i > 0) row.add(_buildDividerVisual(i - 1));
          row.add(SizedBox(
            width: widths[i],
            child: widget.controller.pageAt(i),
          ));
        }
        // Absorbs any slack when the pages' widths don't fill the row.
        row.add(const Spacer());

        // The drag areas are overlaid instead of wrapping the visual: that
        // decouples "how big the divider looks" from "how easy it is to
        // grab" without either one distorting the layout.
        //
        // Offsets accumulate from the row's leading edge — the right edge
        // under RTL — so they are measured with `start`, not `left`.
        final textDirection = Directionality.of(context);
        final handles = <Widget>[];
        var offset = 0.0;
        for (var i = 0; i < paneCount - 1; i++) {
          offset += widths[i];
          handles.add(_buildDragHandle(
            i,
            offset + widget.dividerWidth / 2,
            panesWidth,
            textDirection,
          ));
          offset += widget.dividerWidth;
        }

        return Stack(
          // The row keeps sizing the view exactly as it did before the
          // handles were added.
          fit: StackFit.passthrough,
          children: [Row(children: row), ...handles],
        );
      },
    );
  }

  Widget _buildDividerVisual(int dividerIndex) {
    final builder = widget.dividerBuilder;
    // Fixed slot (dividerWidth × full height) keeps the layout math stable
    // regardless of what the builder paints inside.
    return SizedBox(
      width: widget.dividerWidth,
      height: double.infinity,
      child: builder != null
          ? builder(context, dividerIndex)
          : Container(color: widget.dividerColor),
    );
  }

  Widget _buildDragHandle(
    int dividerIndex,
    double centerFromStart,
    double panesWidth,
    TextDirection textDirection,
  ) {
    final hitWidth = math.max(widget.dividerWidth, widget.dividerHitWidth);
    return Positioned.directional(
      textDirection: textDirection,
      start: centerFromStart - hitWidth / 2,
      top: 0,
      bottom: 0,
      width: hitWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        // Translucent, so the pane content and the divider's own visual keep
        // receiving pointer and hover events under the handle.
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) =>
              _handleDragStart(dividerIndex, details.globalPosition.dx),
          onHorizontalDragUpdate: (details) => _handleDragUpdate(
            panesWidth,
            details.globalPosition.dx,
            textDirection,
          ),
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: _handleDragEnd,
        ),
      ),
    );
  }

  /// Per-pane width limits in pixels.
  ///
  /// Minimums that cannot all fit are dropped: enforcing them would leave
  /// every pane already below its floor with nothing to give, freezing the
  /// divider. Dropping them lets the drag move freely instead.
  ({List<double> min, List<double> max}) _limits(
    int count,
    double panesWidth,
  ) {
    final min = List<double>.generate(count, (i) {
      return VitMultiPanePage.minWidthOf(widget.controller.pageAt(i)) ?? 0.0;
    });
    final max = List<double>.generate(count, (i) {
      final value =
          VitMultiPanePage.maxWidthOf(widget.controller.pageAt(i)) ??
              double.infinity;
      return math.max(value, min[i]);
    });
    if (min.fold<double>(0, (a, b) => a + b) > panesWidth + _epsilon) {
      return (min: List<double>.filled(count, 0), max: max);
    }
    return (min: min, max: max);
  }

  /// Indices from [from] down to 0 — panes to the left of a divider, nearest
  /// first.
  List<int> _towardStart(int from) =>
      List<int>.generate(from + 1, (i) => from - i);

  /// Indices from [from] up to [count] - 1 — panes to the right of a
  /// divider, nearest first.
  List<int> _towardEnd(int from, int count) =>
      List<int>.generate(math.max(0, count - from), (i) => from + i);

  /// Total room available across [order], per [headroom].
  double _totalHeadroom(List<int> order, double Function(int i) headroom) {
    var total = 0.0;
    for (final i in order) {
      final room = headroom(i);
      if (room.isInfinite) return double.infinity;
      if (room > 0) total += room;
    }
    return total;
  }

  /// Adds `sign * amount` pixels across [order], giving each pane as much as
  /// its [headroom] allows before moving on to the next one. Visiting the
  /// panes nearest the divider first is what makes a drag feel local: the
  /// neighbour resizes alone, and the panes beyond it only start moving once
  /// it has hit its own limit.
  void _shift(
    List<int> order,
    List<double> widths,
    double amount,
    double sign,
    double Function(int i) headroom,
  ) {
    var remaining = amount;
    for (final i in order) {
      if (remaining <= _epsilon) return;
      final step = math.min(remaining, headroom(i));
      if (step <= 0) continue;
      widths[i] += sign * step;
      remaining -= step;
    }
  }

  void _handleDragStart(int dividerIndex, double globalX) {
    _activeDivider = dividerIndex;
    _dragStartX = globalX;
    // Snapshotted as fractions, not pixels, so a window resize mid-drag
    // rescales the grabbed layout instead of stretching it.
    _dragStartFractions = List<double>.of(_fractions);
  }

  void _handleDragUpdate(
    double panesWidth,
    double globalX,
    TextDirection textDirection,
  ) {
    final dividerIndex = _activeDivider;
    if (dividerIndex == null || panesWidth <= 0) return;
    final count = _dragStartFractions.length;
    if (count != _fractions.length || dividerIndex + 1 >= count) return;

    final limits = _limits(count, panesWidth);
    final widths = List<double>.generate(
      count,
      (i) => _dragStartFractions[i] * panesWidth,
    );

    // Absolute travel since the grab — not a per-frame increment — so the
    // divider lands exactly where the pointer is, at pixel granularity.
    // Under RTL the panes run right-to-left, so moving right eats into the
    // leading pane rather than growing it.
    final delta = (globalX - _dragStartX) *
        (textDirection == TextDirection.rtl ? -1 : 1);
    final towardEnd = delta >= 0;
    final growing = towardEnd
        ? _towardStart(dividerIndex)
        : _towardEnd(dividerIndex + 1, count);
    final shrinking = towardEnd
        ? _towardEnd(dividerIndex + 1, count)
        : _towardStart(dividerIndex);

    // Grow and shrink sides are disjoint, so both callbacks read untouched
    // widths regardless of the order the two _shift calls run in.
    double growRoom(int i) => limits.max[i] - widths[i];
    double shrinkRoom(int i) => widths[i] - limits.min[i];

    // One side can be at its limit while the other still has room; moving
    // the smaller of the two keeps the total width constant.
    final amount = math.min(
      delta.abs(),
      math.min(
        _totalHeadroom(growing, growRoom),
        _totalHeadroom(shrinking, shrinkRoom),
      ),
    );
    _shift(growing, widths, amount, 1, growRoom);
    _shift(shrinking, widths, amount, -1, shrinkRoom);

    // Recomputed from the snapshot every time, so this is also how a drag
    // back toward the origin undoes itself exactly.
    var changed = false;
    for (var i = 0; i < count; i++) {
      if ((widths[i] / panesWidth - _fractions[i]).abs() > _epsilon) {
        changed = true;
        break;
      }
    }
    if (!changed) return;

    setState(() {
      for (var i = 0; i < count; i++) {
        _fractions[i] = widths[i] / panesWidth;
      }
    });
  }

  void _handleDragEnd() {
    _activeDivider = null;
    _dragStartFractions = const [];
  }
}
