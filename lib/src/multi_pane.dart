/// The controller and the view are one library, split across two files.
///
/// Not a stylistic choice: Dart's privacy is per-library, so this is what
/// lets the view register itself with the controller through members
/// (`_registerView` / `_unregisterView`, `_ProportionsCallback`) that stay
/// invisible outside the package. As separate libraries they would have to
/// be public API, and nobody using this package should ever see them.
///
/// Everything a part file needs is imported here.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'pane_proportions.dart';
import 'vit_multi_pane_page.dart';

part 'divider_info.dart';
part 'vit_multi_pane_controller.dart';
part 'vit_multi_pane_view.dart';
