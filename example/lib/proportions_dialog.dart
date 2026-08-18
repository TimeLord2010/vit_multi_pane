import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for one proportion per page and returns the request, ready to hand to
/// `VitMultiPaneController.setProportions` — or null when it is dismissed.
///
/// A page marked "restante" contributes [double.infinity]; the others
/// contribute the fraction typed in their field.
Future<List<double>?> showProportionsDialog(
  BuildContext context, {
  required List<String> pageLabels,
}) {
  return showDialog<List<double>>(
    context: context,
    builder: (context) => _ProportionsDialog(pageLabels: pageLabels),
  );
}

class _ProportionsDialog extends StatefulWidget {
  const _ProportionsDialog({required this.pageLabels});

  final List<String> pageLabels;

  @override
  State<_ProportionsDialog> createState() => _ProportionsDialogState();
}

class _ProportionsDialogState extends State<_ProportionsDialog> {
  late final List<TextEditingController> _fields;
  late final List<bool> _fills;
  String? _error;

  int get _pageCount => widget.pageLabels.length;

  @override
  void initState() {
    super.initState();
    final even = (1 / _pageCount).toStringAsFixed(2);
    _fields = List.generate(
      _pageCount,
      (_) => TextEditingController(text: even),
    );
    _fills = List<bool>.filled(_pageCount, false);
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  /// Reads the form, or sets [_error] and returns null.
  List<double>? _read() {
    final request = <double>[];
    for (var i = 0; i < _pageCount; i++) {
      if (_fills[i]) {
        request.add(double.infinity);
        continue;
      }
      final text = _fields[i].text.trim().replaceAll(',', '.');
      final value = double.tryParse(text);
      if (value == null) {
        setState(() {
          _error = '"${widget.pageLabels[i]}": '
              '${text.isEmpty ? 'valor vazio' : '"$text" não é um número'}.';
        });
        return null;
      }
      request.add(value);
    }
    return request;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the fixed pages count: the flexible ones take whatever is left.
    final typed = [
      for (var i = 0; i < _pageCount; i++)
        if (!_fills[i]) double.tryParse(_fields[i].text.replaceAll(',', '.'))
    ];
    final fixedSum = typed.fold<double>(0, (sum, v) => sum + (v ?? 0));
    final flexCount = _fills.where((fill) => fill).length;

    return AlertDialog(
      title: const Text('Definir proporções'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uma fração de 0 a 1 por página. "Restante" (∞) reparte o que '
              'sobrar. Valores fixos que não somam 1 são lidos como razão.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _pageCount; i++) _buildRow(i),
            const Divider(height: 24),
            Text(
              flexCount == 0
                  ? 'Soma: ${fixedSum.toStringAsFixed(2)}'
                      '${(fixedSum - 1).abs() < 0.005 ? '' : ' → normalizada'}'
                  : 'Fixo: ${fixedSum.toStringAsFixed(2)} · '
                      'restante repartido entre $flexCount '
                      '${flexCount == 1 ? 'página' : 'páginas'}',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final request = _read();
            if (request != null) Navigator.of(context).pop(request);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildRow(int index) {
    final fills = _fills[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.pageLabels[index],
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _fields[index],
              enabled: !fills,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: fills ? '∞' : null,
              ),
              // Keeps the "soma" line honest while typing.
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('restante'),
            selected: fills,
            onSelected: (selected) => setState(() {
              _fills[index] = selected;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }
}
