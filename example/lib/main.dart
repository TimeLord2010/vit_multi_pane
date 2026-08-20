import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vit_multi_pane/vit_multi_pane.dart';
import 'package:vit_multi_pane_example/proportions_dialog.dart';

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

/// All pages in the controller are always visible, nothing hidden. The FAB
/// is the "floating component" — it manages pages through the controller.
class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  final _controller = VitMultiPaneController();

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
                    onDistributeEvenly: _distributeEvenly,
                    onEditProportions: _editProportions,
                  ),
                  Expanded(
                    child: VitMultiPaneView(
                      controller: _controller,
                      // Metade para a primeira página; as outras duas
                      // dividem o resto.
                      initialProportions: const [
                        0.5,
                        double.infinity,
                        double.infinity,
                      ],
                      dividerBuilder: (context, dividerIndex, isMouseOver) {
                        return Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 233, 233, 233),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 150),
                              width: 2,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: .circular(20),
                                color: Color.fromARGB(
                                  isMouseOver ? 255 : 100,
                                  145,
                                  145,
                                  145,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _controller.add(_buildPage('Página ${_controller.length + 1}'));
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar página'),
      ),
    );
  }

  /// Every page asks for "the rest of the space", so they all get the same
  /// slice.
  void _distributeEvenly() {
    _controller.setProportions(
      List.filled(_controller.length, double.infinity),
    );
  }

  /// Hands the split over to the user: one value per page, applied straight
  /// to the controller.
  Future<void> _editProportions() async {
    final messenger = ScaffoldMessenger.of(context);
    final request = await showProportionsDialog(
      context,
      pageLabels: [for (var i = 0; i < _controller.length; i++) _labelAt(i)],
    );
    if (request == null) return;

    try {
      _controller.setProportions(request);
    } on ArgumentError catch (error) {
      // The package rejects a malformed request instead of guessing — showing
      // that here is half the point of the demo.
      messenger.showSnackBar(
        SnackBar(content: Text('Recusado: ${error.message}')),
      );
    }
  }

  /// The page's own title, for the dialog's rows.
  String _labelAt(int index) {
    final page = _controller.pageAt(index);
    final child = page is VitMultiPanePage ? page.child : page;
    return child is _DemoPage ? child.label : 'Página ${index + 1}';
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
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.width,
    required this.pageCount,
    required this.currentIndex,
    required this.onDistributeEvenly,
    required this.onEditProportions,
  });

  final double width;
  final int pageCount;
  final int currentIndex;
  final VoidCallback onDistributeEvenly;
  final VoidCallback onEditProportions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'largura: ${width.round()}px · páginas: $pageCount · '
              'atual: $currentIndex',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: pageCount == 0 ? null : onDistributeEvenly,
            child: const Text('Distribuir igualmente'),
          ),
          TextButton(
            onPressed: pageCount == 0 ? null : onEditProportions,
            child: const Text('Definir proporções…'),
          ),
        ],
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
