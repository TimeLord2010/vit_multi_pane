/// Shared rules for a proportions request — the list of per-page fractions
/// accepted by `VitMultiPaneController.setProportions` and
/// `VitMultiPaneView.initialProportions`.
///
/// Internal to the package: both entry points speak the same dialect, so the
/// grammar lives in one place.
library;

/// Returns null when [proportions] is a well-formed request for [pageCount]
/// pages, or a sentence describing what is wrong with it.
String? proportionsProblem(List<double> proportions, int pageCount) {
  if (proportions.length != pageCount) {
    return 'expected exactly one value per page ($pageCount), '
        'got ${proportions.length}';
  }
  for (final value in proportions) {
    if (value.isNaN || value < 0 || (value.isFinite && value > 1)) {
      return 'each value must be between 0 and 1, or double.infinity '
          '(got $value)';
    }
  }
  if (proportions.every((value) => value == 0)) {
    return 'at least one value must be greater than 0';
  }
  return null;
}

/// Turns a request into fractions of the panes area that sum to 1.
///
/// [double.infinity] means "take whatever is left", split equally between all
/// infinite entries. Finite values only express a ratio, so they are
/// normalized when they don't add up to 1 on their own.
///
/// [proportions] must have passed [proportionsProblem] first.
List<double> resolveProportions(List<double> proportions) {
  final resolved = List<double>.of(proportions);
  var infiniteCount = 0;
  var finiteSum = 0.0;
  for (final value in resolved) {
    if (value.isInfinite) {
      infiniteCount++;
    } else {
      finiteSum += value;
    }
  }

  if (infiniteCount == 0) {
    for (var i = 0; i < resolved.length; i++) {
      resolved[i] /= finiteSum;
    }
    return resolved;
  }

  // The fixed pages are served first; the flexible ones split what is left.
  // Nothing left (the fixed pages already ask for the whole width, or more)
  // collapses them to zero rather than overflowing the row.
  final scale = finiteSum > 1 ? 1 / finiteSum : 1.0;
  final share = finiteSum >= 1 ? 0.0 : (1 - finiteSum) / infiniteCount;
  for (var i = 0; i < resolved.length; i++) {
    resolved[i] = resolved[i].isInfinite ? share : resolved[i] * scale;
  }
  return resolved;
}
