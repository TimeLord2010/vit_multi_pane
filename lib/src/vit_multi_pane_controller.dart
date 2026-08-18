import 'package:flutter/widgets.dart';

/// Owns the list of pages shown by [VitMultiPaneView].
///
/// The controller is required (no internal state): the app is the single
/// source of truth for which pages exist. Pages are plain [Widget]s; a page
/// may optionally be a [VitMultiPanePage] to carry width metadata.
class VitMultiPaneController extends ChangeNotifier {
  final List<Widget> _pages = [];
  int _currentIndex = 0;

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
}
