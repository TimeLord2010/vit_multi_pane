import 'package:flutter/material.dart';

class MouseHoverListener extends StatefulWidget {
  const MouseHoverListener({super.key, this.child, required this.builder});
  final Widget? child;
  final Widget Function(BuildContext context, bool isMouseOver, Widget? child)
  builder;

  @override
  State<MouseHoverListener> createState() => _MouseHoverListenerState();
}

class _MouseHoverListenerState extends State<MouseHoverListener> {
  bool isMouseOver = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: widget.builder(context, isMouseOver, widget.child),
      onEnter: (event) {
        isMouseOver = true;
        setState(() {});
      },
      onExit: (event) {
        isMouseOver = false;
        setState(() {});
      },
    );
  }
}
