part of 'multi_pane.dart';

/// How a [VitMultiPaneView] receives a layout command from the controller
/// it is rendering. The fractions add up to 1, one per page.
typedef _ProportionsCallback = void Function(List<double> fractions);

/// Owns the list of pages shown by [VitMultiPaneView].
///
/// The controller is required (no internal state): the app is the single
/// source of truth for which pages exist. Pages are plain [Widget]s; a page
/// may optionally be a [VitMultiPanePage] to carry width metadata.
class VitMultiPaneController extends ChangeNotifier {
  final List<Widget> _pages = [];
  int _currentIndex = 0;

  /// The views rendering these pages right now — how [setProportions]
  /// reaches them. Filled and emptied by the views' own lifecycle, exactly
  /// like the listener list [ChangeNotifier] already keeps underneath.
  final List<_ProportionsCallback> _views = [];

  /// Unmodifiable snapshot of the pages, in order.
  List<Widget> get pages => List.unmodifiable(_pages);

  /// Number of pages.
  int get length => _pages.length;

  /// Index of the currently active page.
  int get currentIndex => _currentIndex;

  /// Returns the page at [index].
  Widget pageAt(int index) => _pages[index];

  /// Appends [page] to the end of the list.
  void add(Widget page) {
    _pages.add(page);
    notifyListeners();
  }

  /// Replaces the page at [index] with [page].
  void replaceAt(int index, Widget page) {
    RangeError.checkValidIndex(index, _pages, 'index', length);
    _pages[index] = page;
    notifyListeners();
  }

  /// Removes the page at [index].
  ///
  /// If the current page was after the removed one, [currentIndex] shifts
  /// down to stay in range.
  void removeAt(int index) {
    RangeError.checkValidIndex(index, _pages, 'index', length);
    _pages.removeAt(index);
    if (_pages.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= _pages.length) {
      _currentIndex = _pages.length - 1;
    }
    notifyListeners();
  }

  /// Sets the currently active page.
  void setCurrentIndex(int index) {
    RangeError.checkValidIndex(index, _pages, 'index', length);
    if (index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Splits the horizontal space between the pages, right now.
  ///
  /// One value per page, each a fraction of the area available to the panes
  /// (dividers excluded). [double.infinity] means "take whatever is left",
  /// shared equally between all infinite entries:
  ///
  /// ```dart
  /// controller.setProportions([0.5, double.infinity, double.infinity]);
  /// // → 50% for the first page, 25% for each of the other two.
  /// ```
  ///
  /// Finite values are normalized when they don't add up to 1, so
  /// `[0.33, 0.33, 0.33]` and `[1, 1, 1]` both mean "even thirds". If they
  /// add up to more than 1, they are scaled down to fit and the infinite
  /// entries get nothing.
  ///
  /// Each page's `minWidth` / `maxWidth` still wins: the view clamps the
  /// resulting widths, so a page can end up wider or narrower than asked.
  ///
  /// This is a one-shot command, not a setting: it re-lays out the view and
  /// is then forgotten. The user is free to drag the dividers afterwards, and
  /// adding or removing a page resets the panes to an even split. Because
  /// nothing is stored, it only affects a view that is already in the tree —
  /// calling it before the first build does nothing (and asserts in debug).
  /// To declare the layout the panes start with, use
  /// [VitMultiPaneView.initialProportions] instead.
  ///
  /// Throws an [ArgumentError] when the list doesn't have exactly one value
  /// per page, when a value is negative, NaN or a finite value above 1, or
  /// when every value is zero.
  void setProportions(List<double> proportions) {
    final problem = proportionsProblem(proportions, _pages.length);
    if (problem != null) {
      throw ArgumentError.value(proportions, 'proportions', problem);
    }
    assert(
      _views.isNotEmpty,
      'setProportions() was called on a controller that no VitMultiPaneView '
      'is rendering, so it had no effect. Call it once the view is in the '
      'tree — from a button, a post-frame callback, etc. To declare the '
      'layout the panes start with, use VitMultiPaneView.initialProportions.',
    );

    final fractions = resolveProportions(proportions);
    // Copied: a view may be disposed while the command is being handed out.
    for (final apply in List.of(_views)) {
      apply(fractions);
    }
  }

  /// Called by [VitMultiPaneView] from its `initState`.
  void _registerView(_ProportionsCallback callback) {
    _views.add(callback);
  }

  /// Called by [VitMultiPaneView] from its `dispose`.
  void _unregisterView(_ProportionsCallback callback) {
    _views.remove(callback);
  }
}
