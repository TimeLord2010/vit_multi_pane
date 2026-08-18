import 'package:flutter/widgets.dart';

/// A page optionally annotated with width constraints.
///
/// The package treats any [Widget] added to the controller as a page. When
/// the page is a [VitMultiPanePage], the [minWidth] / [maxWidth] metadata is
/// available to the layout (e.g. to clamp the draggable divider).
class VitMultiPanePage extends StatelessWidget {
  const VitMultiPanePage({
    super.key,
    required this.child,
    this.minWidth,
    this.maxWidth,
  })  : assert(minWidth == null || minWidth >= 0),
        assert(maxWidth == null || maxWidth >= 0),
        assert(
          minWidth == null || maxWidth == null || minWidth <= maxWidth,
          'minWidth must be <= maxWidth',
        );

  /// The actual page content.
  final Widget child;

  /// Minimum width this page may occupy, in logical pixels.
  final double? minWidth;

  /// Maximum width this page may occupy, in logical pixels.
  final double? maxWidth;

  /// Returns the minimum width of [page], or null when [page] is not a
  /// [VitMultiPanePage] (or declares no [minWidth]).
  static double? minWidthOf(Widget page) =>
      page is VitMultiPanePage ? page.minWidth : null;

  /// Returns the maximum width of [page], or null when [page] is not a
  /// [VitMultiPanePage] (or declares no [maxWidth]).
  static double? maxWidthOf(Widget page) =>
      page is VitMultiPanePage ? page.maxWidth : null;

  @override
  Widget build(BuildContext context) => child;
}
