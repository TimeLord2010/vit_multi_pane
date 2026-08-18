# vit_multi_pane example

Runnable demo of the `vit_multi_pane` package.

Every page added via the FAB is **immediately visible** — the example uses
the simplest rule (all pages always visible, draggable divider between them).
Apps that want breakpoint logic (1 page on mobile, N on desktop) plug their
own function into `visibleIndices` — the package itself stays ignorant.

See the package root `README.md` for usage.
