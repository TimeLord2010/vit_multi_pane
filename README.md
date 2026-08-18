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
- **Pixel-exact drag** — the divider sits under the pointer, one screen pixel
  per pixel of travel, and a drag moves only the two panes it sits between
  (spilling onto the ones beyond only once a neighbour reaches its own
  `minWidth` / `maxWidth`). `dividerHitWidth` (12px by default) sets how wide
  the grab area is, independently of how thin the divider looks.

## Usage

```dart
final controller = VitMultiPaneController()
  ..add(VitMultiPanePage(minWidth: 240, child: const HomePage()))
  ..add(VitMultiPanePage(minWidth: 240, child: const ReportsPage()));

VitMultiPaneView(controller: controller);
```

See `example/` for a runnable demo.
