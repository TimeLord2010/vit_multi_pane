# vit_multi_pane

Multi-pane layout for Flutter: pages are shown side by side with a
draggable divider between them.

## Features

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

VitMultiPaneView(controller: controller);
```

See `example/` for a runnable demo.
