import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

    test('setProportions rejects malformed requests', () {
      final controller = VitMultiPaneController()
        ..add(const SizedBox())
        ..add(const SizedBox());

      expect(() => controller.setProportions([0.5]), throwsArgumentError);
      expect(() => controller.setProportions([0.3, 0.3, 0.4]),
          throwsArgumentError);
      expect(() => controller.setProportions([-0.5, 0.5]),
          throwsArgumentError);
      expect(() => controller.setProportions([1.5, 0.5]),
          throwsArgumentError);
      expect(() => controller.setProportions([double.nan, 0.5]),
          throwsArgumentError);
      expect(() => controller.setProportions([0, 0]), throwsArgumentError);
    });

    test('setProportions asserts when no view is rendering the pages', () {
      final controller = VitMultiPaneController()
        ..add(const SizedBox())
        ..add(const SizedBox());

      // Nothing is stored, so a command with no view to act on is a silent
      // no-op in release — worth catching while developing.
      expect(() => controller.setProportions([0.3, 0.7]),
          throwsAssertionError);
    });
  });

  group('VitMultiPaneView', () {
    Widget wrap(VitMultiPaneController controller, {double width = 400}) {
      // Center is required: MaterialApp home gives TIGHT 800x600 constraints
      // and a plain SizedBox cannot shrink inside tight constraints.
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 200,
            child: VitMultiPaneView(controller: controller),
          ),
        ),
      );
    }

    testWidgets('shows a single pane when the controller has one page',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')));

      await tester.pumpWidget(wrap(controller));

      expect(find.byKey(const Key('pane0')), findsOneWidget);
    });

    testWidgets('shows all pages from the controller side by side',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));

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

      await tester.pumpWidget(wrap(controller));

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
      await tester.pumpWidget(wrap(controller));

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
      await tester.pumpWidget(wrap(controller));

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
      await tester.pumpWidget(wrap(controller));

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

  group('VitMultiPaneView drag precision', () {
    Widget wrap(VitMultiPaneController controller, {double width = 400}) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 200,
            child: VitMultiPaneView(controller: controller),
          ),
        ),
      );
    }

    /// Presses on the divider to the right of [leftPane].
    ///
    /// A mouse drag is recognized after ~1px of travel and that travel is
    /// then applied in full, so total pointer distance from this press maps
    /// one-to-one onto pane widths and assertions can be exact. The first
    /// `moveBy` of a gesture must therefore exceed 1px.
    Future<TestGesture> grabDivider(
      WidgetTester tester,
      Finder leftPane, {
      double offsetFromCenter = 0,
    }) async {
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      // Default dividerWidth is 4, so its center is 2px past the left pane.
      final centerX = tester.getTopRight(leftPane).dx + 2;
      final gesture = await tester.startGesture(
        Offset(centerX + offsetFromCenter, viewTop + 100),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      return gesture;
    }

    double widthOf(WidgetTester tester, String key) =>
        tester.getSize(find.byKey(Key(key))).width;

    testWidgets('divider follows the pointer across many small updates',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));
      final before = widthOf(tester, 'pane0'); // (400-4)/2 = 198

      final gesture = await grabDivider(tester, find.byKey(const Key('pane0')));

      // 20 updates × 2px. Scaling the *current* widths by a factor derived
      // from the *start* widths compounded on every update, so a drag this
      // short used to blow past the layout limit and pin itself there.
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(2, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before + 40, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(before - 40, 0.5));
    });

    testWidgets('a one-pixel drag moves the divider one pixel',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));

      final gesture = await grabDivider(tester, find.byKey(const Key('pane0')));
      // Past the recognizer's 1px threshold, then move one pixel at a time.
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();
      final before = widthOf(tester, 'pane0');

      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(before + 1, 0.01));

      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(before + 2, 0.01));
      await gesture.up();
    });

    testWidgets('dragging back to the grab point restores the widths',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));
      final before = widthOf(tester, 'pane0');

      final gesture = await grabDivider(tester, find.byKey(const Key('pane0')));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(before + 50, 0.5));

      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before, 0.5));
    });

    testWidgets('a drag only resizes the two panes it sits between',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')))
        ..add(const SizedBox(key: Key('pane2')));

      await tester.pumpWidget(wrap(controller));
      final before = widthOf(tester, 'pane0'); // (400-8)/3 ≈ 130.67

      final gesture = await grabDivider(tester, find.byKey(const Key('pane0')));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before + 30, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(before - 30, 0.5));
      // The far pane stays put: dividers move one boundary, not all of them.
      expect(widthOf(tester, 'pane2'), closeTo(before, 0.5));
    });

    testWidgets('the drag cascades past a neighbour that hit its minimum',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const VitMultiPanePage(
          key: Key('pane1'),
          minWidth: 100,
          child: SizedBox(),
        ))
        ..add(const SizedBox(key: Key('pane2')));

      await tester.pumpWidget(wrap(controller));
      final before = widthOf(tester, 'pane0'); // ≈130.67

      // 60px right: pane1 can only give up ~30.67 before hitting its 100px
      // minimum, so pane2 covers the rest instead of the drag stalling.
      final gesture = await grabDivider(tester, find.byKey(const Key('pane0')));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before + 60, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(100, 0.5));
      expect(widthOf(tester, 'pane2'), closeTo(before - 29.33, 0.5));
    });

    testWidgets('the divider is grabbable a few pixels off its visual',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));
      final before = widthOf(tester, 'pane0');

      // 5px off center is outside the 4px visual but inside the 12px hit
      // area — a hairline divider still needs to be easy to catch.
      final gesture = await grabDivider(
        tester,
        find.byKey(const Key('pane0')),
        offsetFromCenter: 5,
      );
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before + 25, 0.5));
    });

    testWidgets('under RTL the drag follows the pointer the other way',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: VitMultiPaneView(controller: controller),
            ),
          ),
        ),
      ));

      // pane0 is the leading pane, so under RTL it sits on the right and its
      // divider is on its LEFT.
      final pane0 = find.byKey(const Key('pane0'));
      final before = widthOf(tester, 'pane0');
      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerCenter = tester.getTopLeft(pane0).dx - 2;

      final gesture = await tester.startGesture(
        Offset(dividerCenter, viewTop + 100),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      // Dragging left grows the leading pane; dragging right would shrink it.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(before + 30, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(before - 30, 0.5));
    });
  });

  group('VitMultiPaneView proportions', () {
    // 400px wide; with three panes the two 4px dividers leave 392px to split.
    Widget wrap(VitMultiPaneController controller) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: VitMultiPaneView(controller: controller),
          ),
        ),
      );
    }

    double widthOf(WidgetTester tester, String key) =>
        tester.getSize(find.byKey(Key(key))).width;

    VitMultiPaneController threePanes() => VitMultiPaneController()
      ..add(const SizedBox(key: Key('pane0')))
      ..add(const SizedBox(key: Key('pane1')))
      ..add(const SizedBox(key: Key('pane2')));

    testWidgets('setProportions splits the space as asked', (tester) async {
      final controller = threePanes();
      await tester.pumpWidget(wrap(controller));

      controller.setProportions([0.5, 0.25, 0.25]);
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(196, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(98, 0.5));
      expect(widthOf(tester, 'pane2'), closeTo(98, 0.5));
    });

    testWidgets('infinity shares whatever the fixed pages leave',
        (tester) async {
      final controller = threePanes();
      await tester.pumpWidget(wrap(controller));

      controller.setProportions([0.5, double.infinity, double.infinity]);
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(196, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(98, 0.5));
      expect(widthOf(tester, 'pane2'), closeTo(98, 0.5));
    });

    testWidgets('an all-infinity request spreads the panes evenly',
        (tester) async {
      final controller = threePanes();
      await tester.pumpWidget(wrap(controller));

      controller.setProportions([0.9, 0.05, 0.05]);
      await tester.pump();
      controller.setProportions(List.filled(3, double.infinity));
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(392 / 3, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(392 / 3, 0.5));
      expect(widthOf(tester, 'pane2'), closeTo(392 / 3, 0.5));
    });

    testWidgets('finite values that do not add up to 1 are read as a ratio',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));
      await tester.pumpWidget(wrap(controller));

      // 396px to split, 1:3 → 99 / 297.
      controller.setProportions([0.25, 0.75]);
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));

      // Same ratio written as thirds of nothing in particular.
      controller.setProportions([0.2, 0.6]);
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(297, 0.5));
    });

    testWidgets('minWidth still wins over the requested split',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const VitMultiPanePage(
          key: Key('pane0'),
          minWidth: 300,
          child: SizedBox(),
        ))
        ..add(const SizedBox(key: Key('pane1')));
      await tester.pumpWidget(wrap(controller));

      // 25% of 396 is 99px, below pane0's floor: it keeps 300 and pane1 takes
      // what is left instead of the row overflowing.
      controller.setProportions([0.25, 0.75]);
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(300, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(96, 0.5));
    });

    testWidgets('the dividers stay draggable from the new split',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));
      await tester.pumpWidget(wrap(controller));

      controller.setProportions([0.25, 0.75]);
      await tester.pump();

      final viewTop = tester.getTopLeft(find.byType(VitMultiPaneView)).dy;
      final dividerX =
          tester.getTopRight(find.byKey(const Key('pane0'))).dx + 2;
      final gesture = await tester.startGesture(
        Offset(dividerX, viewTop + 100),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(widthOf(tester, 'pane0'), closeTo(129, 0.5));
    });

    testWidgets('a command is one-shot: adding a page evens the panes out',
        (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));
      await tester.pumpWidget(wrap(controller));

      controller.setProportions([0.25, 0.75]);
      await tester.pump();
      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));

      controller.add(const SizedBox(key: Key('pane2')));
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(392 / 3, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(392 / 3, 0.5));
      expect(widthOf(tester, 'pane2'), closeTo(392 / 3, 0.5));
    });

    testWidgets('initialProportions lays the panes out on the first frame',
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
              initialProportions: const [0.25, double.infinity],
            ),
          ),
        ),
      ));

      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));
      expect(widthOf(tester, 'pane1'), closeTo(297, 0.5));
    });

    testWidgets('initialProportions waits for the pages to show up',
        (tester) async {
      // An empty controller has no panes to lay out, so the declared split
      // applies whenever the pages do arrive — not on the widget's own first
      // build, which happens before them.
      final controller = VitMultiPaneController();

      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: VitMultiPaneView(
              controller: controller,
              initialProportions: const [0.25, 0.75],
            ),
          ),
        ),
      ));

      controller
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));
    });

    testWidgets('initialProportions only describes the first layout',
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
              initialProportions: const [0.25, 0.75],
            ),
          ),
        ),
      ));
      expect(widthOf(tester, 'pane0'), closeTo(99, 0.5));

      // A third page re-splits the row evenly instead of reviving the
      // declared 1:3 — from here on the layout is the user's.
      controller.add(const SizedBox(key: Key('pane2')));
      await tester.pump();

      expect(widthOf(tester, 'pane0'), closeTo(392 / 3, 0.5));
    });

    testWidgets('a malformed initialProportions is reported and ignored',
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
              initialProportions: const [0.25, 0.25, 0.5], // one page short
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('a disposed view stops receiving commands', (tester) async {
      final controller = VitMultiPaneController()
        ..add(const SizedBox(key: Key('pane0')))
        ..add(const SizedBox(key: Key('pane1')));

      await tester.pumpWidget(wrap(controller));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Detached again: the assert is the tell that nothing is listening.
      expect(() => controller.setProportions([0.25, 0.75]),
          throwsAssertionError);
    });
  });
}
