part of 'multi_pane.dart';

/// Interaction state of one divider, passed to
/// [VitMultiPaneView.dividerBuilder].
///
/// Groups everything the builder may want to know about the divider's
/// current situation in a single object, so the builder signature stays
/// short and new state (hover, dragging, …) becomes a field instead of a
/// new parameter.
class DividerInfo {
  const DividerInfo({
    required this.dividerIndex,
    required this.isMouseOver,
    required this.isDragging,
  });

  /// Index of this divider, 0-based, between panes `index` and `index + 1`.
  final int dividerIndex;

  /// Whether the pointer is over this divider's drag handle (the
  /// [VitMultiPaneView.dividerHitWidth]-wide strip), not just over the
  /// usually much thinner visual.
  final bool isMouseOver;

  /// Whether this divider is being dragged right now.
  final bool isDragging;
}
