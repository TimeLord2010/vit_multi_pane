import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vit_multi_pane/vit_multi_pane.dart';

void main() {
  runApp(const VitMultiPaneExampleApp());
}

class VitMultiPaneExampleApp extends StatelessWidget {
  const VitMultiPaneExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vit_multi_pane example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      ),
      home: const ExampleHome(),
    );
  }
}

enum _Action { add, replace, next }

/// All pages in the controller are always visible, nothing hidden. The FAB
/// is the "floating component" — it manages pages through the controller.
class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  final VitMultiPaneController _controller = VitMultiPaneController();

  @override
  void initState() {
    super.initState();
    _controller.add(_buildPage('Início'));
    _controller.add(_buildPage('Relatórios'));
    _controller.add(_buildPage('Configurações'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  VitMultiPanePage _buildPage(
    String label, {
    Color? color,
    double? minWidth = 240,
    double? maxWidth = 720,
  }) {
    final pageColor =
        color ?? Colors.primaries[_controller.length % Colors.primaries.length];
    // The page's own position can shift as other pages are removed, so the
    // close button (and the width-constraint editor) resolves its current
    // index by identity at tap-time instead of capturing a (potentially
    // stale) index at build-time.
    VitMultiPanePage? page;
    page = VitMultiPanePage(
      minWidth: minWidth,
      maxWidth: maxWidth,
      child: _DemoPage(
        label: label,
        color: pageColor,
        minWidth: minWidth,
        maxWidth: maxWidth,
        onClose: () {
          final index = _controller.pages.indexOf(page!);
          if (index != -1) _controller.removeAt(index);
        },
        onConstraintsChanged: (newMinWidth, newMaxWidth) {
          final index = _controller.pages.indexOf(page!);
          if (index != -1) {
            _controller.replaceAt(
              index,
              _buildPage(
                label,
                color: pageColor,
                minWidth: newMinWidth,
                maxWidth: newMaxWidth,
              ),
            );
          }
        },
      ),
    );
    return page;
  }

  Future<void> _showActions() async {
    final action = await showModalBottomSheet<_Action>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Adicionar página'),
              onTap: () => Navigator.pop(sheetContext, _Action.add),
            ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Substituir página atual'),
              onTap: () => Navigator.pop(sheetContext, _Action.replace),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: const Text('Ir para a próxima página'),
              onTap: () => Navigator.pop(sheetContext, _Action.next),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _Action.add:
        // Just add — no hidden logic, no index games. The page appears.
        _controller.add(_buildPage('Página ${_controller.length + 1}'));
        break;
      case _Action.replace:
        if (_controller.length > 0) {
          _controller.replaceAt(
            _controller.currentIndex,
            _buildPage('Nova ${_controller.currentIndex + 1}'),
          );
        }
        break;
      case _Action.next:
        if (_controller.length > 1) {
          _controller.setCurrentIndex(
            (_controller.currentIndex + 1) % _controller.length,
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  _StatusBar(
                    width: width,
                    pageCount: _controller.length,
                    currentIndex: _controller.currentIndex,
                  ),
                  Expanded(child: VitMultiPaneView(controller: _controller)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showActions,
        icon: const Icon(Icons.tune),
        label: const Text('Gerenciar páginas'),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.width,
    required this.pageCount,
    required this.currentIndex,
  });

  final double width;
  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        'largura: ${width.round()}px · páginas: $pageCount · '
        'atual: $currentIndex',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage({
    required this.label,
    required this.color,
    required this.minWidth,
    required this.maxWidth,
    required this.onClose,
    required this.onConstraintsChanged,
  });

  final String label;
  final Color color;
  final double? minWidth;
  final double? maxWidth;
  final VoidCallback onClose;

  /// Called with the parsed field values whenever the user edits either
  /// width field to a valid state (an empty field means "no constraint").
  final void Function(double? minWidth, double? maxWidth) onConstraintsChanged;

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  // Owned by this State (not rebuilt from widget fields) so typing survives
  // the replaceAt-triggered rebuild that every edit causes.
  late final _minController = TextEditingController(
    text: _widthText(widget.minWidth),
  );
  late final _maxController = TextEditingController(
    text: _widthText(widget.maxWidth),
  );

  static String _widthText(double? value) =>
      value == null ? '' : value.toStringAsFixed(0);

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _applyConstraints() {
    final minText = _minController.text;
    final maxText = _maxController.text;
    final min = minText.isEmpty ? null : double.tryParse(minText);
    final max = maxText.isEmpty ? null : double.tryParse(maxText);
    // Ignore states VitMultiPanePage would reject (an unparsable non-empty
    // field, or min > max) — the user is still mid-edit.
    if ((minText.isNotEmpty && min == null) ||
        (maxText.isNotEmpty && max == null)) {
      return;
    }
    if (min != null && max != null && min > max) return;
    widget.onConstraintsChanged(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Measured HERE, at the page's own boundary: the SizedBox _buildPane wraps
    // this page in gives it a tight width, so this is exactly the pane's
    // on-screen width. Measuring further down the tree would report whatever
    // padding/insets sit in between, not the pane.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildBody(theme, constraints.maxWidth),
    );
  }

  Widget _buildBody(ThemeData theme, double paneWidth) {
    return ColoredBox(
      color: widget.color.withValues(alpha: 0.10),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: widget.color,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.label, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Redimensione a janela — a divisória é arrastável',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Largura atual: ${paneWidth.round()}px',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 90,
                        child: _WidthField(
                          controller: _minController,
                          label: 'Mín (px)',
                          onChanged: _applyConstraints,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: _WidthField(
                          controller: _maxController,
                          label: 'Máx (px)',
                          onChanged: _applyConstraints,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover página',
              onPressed: widget.onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidthField extends StatelessWidget {
  const _WidthField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
