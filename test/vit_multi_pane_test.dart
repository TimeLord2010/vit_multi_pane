import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_multi_pane/vit_multi_pane.dart';

void main() {
  group('VitMultiPaneController', () {
    test('add/replaceAt/removeAt manage the page list', () {
      final controller = VitMultiPaneController();
      const pageA = SizedBox(key: Key('a'));
      const pageB = SizedBox(key: Key('b'));
      const pageC = SizedBox(key: Key('c'));

      controller.add(pageA);
      controller.add(pageB);
      expect(controller.length, 2);
      expect(controller.currentIndex, 0);

      controller.replaceAt(1, pageC);
      expect(controller.pageAt(1), same(pageC));

      controller.removeAt(0);
      expect(controller.length, 1);
      expect(controller.pageAt(0), same(pageC));
    });

    test('removeAt keeps currentIndex in range', () {
      final controller = VitMultiPaneController();
      controller.add(const SizedBox());
      controller.add(const SizedBox());
      controller.add(const SizedBox());
      controller.setCurrentIndex(2);

      controller.removeAt(1);
      expect(controller.length, 2);
      expect(controller.currentIndex, 1);
    });

    test('notifies listeners on mutations', () {
      final controller = VitMultiPaneController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.add(const SizedBox());
      controller.replaceAt(0, const SizedBox());
      controller.setCurrentIndex(0); // no-op: same index
      controller.removeAt(0);

      expect(notifications, 3);
    });

    test('throws RangeError on invalid indices', () {
      final controller = VitMultiPaneController();
      expect(() => controller.replaceAt(0, const SizedBox()),
          throwsRangeError);
      expect(() => controller.removeAt(0), throwsRangeError);
      expect(() => controller.setCurrentIndex(0), throwsRangeError);
    });
  });

  group('VitMultiPaneView', () {
    Widget wrap(VitMultiPaneController controller,
        List<int> Function(BoxConstraints) visibleIndices,
        {double width = 400}) {
      // Center is required: MaterialApp home gives TIGHT 800x600 constraints
      // and a plain SizedBox cannot shrink inside tight constraints.
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 200,
            child: VitMultiPaneView(
              controller: controller,
              visibleIndices: visibleIndices,
            ),
          ),
        ),
      );
    }

    testWidgets('shows a single pane when only one index is visible',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller, (c) => [0]));

      expect(find.byKey(const Key('pane0')), findsOneWidget);
      expect(find.byKey(const Key('pane1')), findsNothing);
    });

    testWidgets('shows panes side by side when multiple indices are visible',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller, (c) => [0, 1]));

      expect(find.byKey(const Key('pane0')), findsOneWidget);
      expect(find.byKey(const Key('pane1')), findsOneWidget);
      final left = tester.getSize(find.byKey(const Key('pane0')));
      final right = tester.getSize(find.byKey(const Key('pane1')));
      expect(left.width, closeTo(right.width, 1));
    });

    testWidgets('dragging the divider resizes the panes', (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller, (c) => [0, 1]));

      final pane0Finder = find.byKey(const Key('pane0'));
      final before = tester.getSize(pane0Finder).width;

      // Drag the divider (4px, right at pane0's right edge) to the RIGHT:
      // the left pane grows. Anchor y inside the view's height.
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerCenter =
          tester.getTopRight(pane0Finder) + Offset(2, 100 - viewTop % 1);
      await tester.dragFrom(
          Offset(dividerCenter.dx, viewTop + 100), const Offset(60, 0));
      await tester.pumpAndSettle();

      final after = tester.getSize(pane0Finder).width;
      expect(after, greaterThan(before));
    });

    testWidgets('initial layout respects minWidth when there is room',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const VitMultiPanePage(
          key: Key('pane0'),
          minWidth: 300,
          child: SizedBox(),
        ))
        ..add(const SizedBox(key: Key('pane1')));

      // 400px total: pane0's 300px minimum fits, so pane1 yields the space
      // and the divider starts at 300px — no snap needed later.
      await tester.pumpWidget(wrap(controller, (c) => [0, 1]));

      final pane0Width = tester.getSize(find.byKey(const Key('pane0'))).width;
      expect(pane0Width, closeTo(300, 1));
    });

    testWidgets('drag is clamped by minWidth when starting from a valid spot',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const VitMultiPanePage(
          key: Key('pane0'),
          minWidth: 300,
          child: SizedBox(),
        ))
        ..add(const SizedBox(key: Key('pane1')));

      // 400px total: pane0 starts at its 300px minimum (pane1 yields).
      await tester.pumpWidget(wrap(controller, (c) => [0, 1]));

      final pane0Finder = find.byKey(const Key('pane0'));
      expect(tester.getSize(pane0Finder).width, closeTo(300, 1));

      // A hard left drag must NOT shrink pane0 below its minimum.
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerX = tester.getTopRight(pane0Finder).dx + 2;
      await tester.dragFrom(Offset(dividerX, viewTop + 100),
          const Offset(-150, 0));
      await tester.pumpAndSettle();

      final pane0Width = tester.getSize(pane0Finder).width;
      expect(pane0Width, closeTo(300, 1));
    });

    testWidgets('custom dividerBuilder renders and stays draggable',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: VitMultiPaneView(
              controller: controller,
              visibleIndices: (c) => [0, 1],
              dividerWidth: 8,
              dividerBuilder: (context, index) => const ColoredBox(
                key: Key('custom-divider'),
                color: Colors.amber,
              ),
            ),
          ),
        ),
      ));

      // The custom widget is rendered in the divider slot.
      expect(find.byKey(const Key('custom-divider')), findsOneWidget);

      // And dragging still resizes the panes.
      final pane0Finder = find.byKey(const Key('pane0'));
      final before = tester.getSize(pane0Finder).width; // (400-8)/2 = 196
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerX = tester.getTopRight(pane0Finder).dx + 4;
      await tester.dragFrom(
          Offset(dividerX, viewTop + 100), const Offset(40, 0));
      await tester.pumpAndSettle();

      final after = tester.getSize(pane0Finder).width;
      expect(after, greaterThan(before));
    });

    testWidgets('drag does not snap when minimums cannot fit',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const VitMultiPanePage(
          key: Key('pane0'),
          minWidth: 240,
          child: SizedBox(),
        ))
        ..add(const VitMultiPanePage(
          key: Key('pane1'),
          minWidth: 240,
          child: SizedBox(),
        ))
        ..add(const VitMultiPanePage(
          key: Key('pane2'),
          minWidth: 240,
          child: SizedBox(),
        ));

      // 400px total vs 720px of minimums: impossible layout. The divider
      // must follow the pointer smoothly instead of snapping to 240px.
      await tester.pumpWidget(wrap(controller, (c) => [0, 1, 2]));

      final pane0Finder = find.byKey(const Key('pane0'));
      final before = tester.getSize(pane0Finder).width; // ~130
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerX = tester.getTopRight(pane0Finder).dx + 2;
      await tester.dragFrom(
          Offset(dividerX, viewTop + 100), const Offset(20, 0));
      await tester.pumpAndSettle();

      final after = tester.getSize(pane0Finder).width;
      expect(after, greaterThan(before)); // moved right a little…
      expect(after, lessThan(240)); // …but nowhere near the min boundary
    });
  });
}
