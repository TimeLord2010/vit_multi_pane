import 'package:flutter/material.dart';
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

enum _Action { add, replace, remove, next }

/// The package owns NO responsive rule — the app decides what to show via
/// [VitMultiPaneView.visibleIndices]. This example uses the simplest honest
/// rule: ALL pages are always visible, nothing hidden. Apps that want
/// breakpoints (1 page on mobile, N on desktop) plug their own function
/// there. The FAB is the "floating component" — it manages pages through
/// the controller.
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

  // The responsive rule lives HERE, in the app — the package stays ignorant.
  // Simplest honest rule: every page is always visible, so adding/removing
  // always has an immediate, obvious effect. An app that wants breakpoints
  // swaps this function for its own (e.g. width-based) logic.
  List<int> _visibleIndices(BoxConstraints _) =>
      [for (var i = 0; i < _controller.length; i++) i];

  VitMultiPanePage _buildPage(String label) {
    final color =
        Colors.primaries[_controller.length % Colors.primaries.length];
    return VitMultiPanePage(
      minWidth: 240,
      maxWidth: 720,
      child: _DemoPage(label: label, color: color),
    );
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
              leading: const Icon(Icons.remove),
              title: const Text('Remover página atual'),
              onTap: () => Navigator.pop(sheetContext, _Action.remove),
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
      case _Action.remove:
        if (_controller.length > 0) {
          _controller.removeAt(_controller.currentIndex);
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
      appBar: AppBar(title: const Text('vit_multi_pane')),
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
                  Expanded(
                    child: VitMultiPaneView(
                      controller: _controller,
                      visibleIndices: _visibleIndices,
                    ),
                  ),
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

class _DemoPage extends StatelessWidget {
  const _DemoPage({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: color.withValues(alpha: 0.10),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 48, color: color),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Redimensione a janela — a divisória é arrastável',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
