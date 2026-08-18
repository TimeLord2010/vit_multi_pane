# vit_multi_pane

Adaptive multi-pane layout for Flutter: one page on narrow screens, several
pages side by side with a draggable divider when there is room.

## Features

- **You own the layout logic** — the package is ignorant of responsive rules.
  `visibleIndices` decides how many and which pages appear for the current
  constraints (e.g. `[current]` on mobile, `[0, 1]` on desktop).
- **Required controller** — pages are plain `Widget`s owned by a
  `VitMultiPaneController` (`add`, `replaceAt`, `removeAt`, `setCurrentIndex`).
- **Draggable dividers** — panes resize by dragging the divider; the optional
  `VitMultiPanePage` wrapper adds `minWidth` / `maxWidth` that clamp it.
  Style the divider yourself with `dividerBuilder` (color, icon, handle — the
  drag behavior stays in the package).

## Usage

```dart
final controller = VitMultiPaneController()
  ..add(VitMultiPanePage(minWidth: 240, child: const HomePage()))
  ..add(VitMultiPanePage(minWidth: 240, child: const ReportsPage()));

VitMultiPaneView(
  controller: controller,
  visibleIndices: (c) =>
      c.maxWidth < 640 ? [controller.currentIndex] : [0, 1],
);
```

See `example/` for a runnable demo.
