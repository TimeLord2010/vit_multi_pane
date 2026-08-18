## Unreleased

* **Fixed** divider drags jumping to a fixed position instead of following the
  pointer. Each drag update scaled the *current* pane widths by a factor
  derived from the widths at drag start, so the error compounded on every
  pointer event and a short drag slammed the divider into its layout limit.
  Updates are now computed from a snapshot taken when the divider is grabbed,
  against the absolute pointer position: the divider tracks the pointer at
  1px granularity and dragging back to the grab point restores the original
  widths exactly.
* **Changed** a drag to resize only the two panes it sits between, spilling
  onto the panes beyond only once a neighbour reaches its own `minWidth` /
  `maxWidth` (it used to rescale every pane on both sides at once).
* **Added** `VitMultiPaneView.dividerHitWidth` (12px default): the grab area
  is now an overlay centered on the divider, so a hairline divider is easy to
  catch without the extra width distorting the layout or swallowing the page
  content's own taps and hovers. Desktop pointers also get a
  `resizeColumn` cursor over it.
* **Fixed** drag direction and divider hit areas under right-to-left
  `Directionality`.

## 0.0.1

* TODO: Describe initial release.
