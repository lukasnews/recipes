import 'package:flutter/material.dart';

import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../domain/baking_pan.dart';

enum PanShape { none, round, rect }

/// Controllers for entering a baking tin (editor and "Andere Form").
class PanInput {
  PanInput([BakingPan? pan])
    : shape = pan == null
          ? PanShape.none
          : (pan.isRound ? PanShape.round : PanShape.rect),
      diameter = TextEditingController(text: _fmt(pan?.diameter)),
      width = TextEditingController(text: _fmt(pan?.width)),
      length = TextEditingController(text: _fmt(pan?.length));

  static String _fmt(double? v) =>
      v == null ? '' : formatAmount(v, fractions: false);

  PanShape shape;
  final TextEditingController diameter;
  final TextEditingController width;
  final TextEditingController length;

  /// Null for "keine" or incomplete sizes.
  BakingPan? get value {
    double? n(TextEditingController c) {
      final v = parseUserNumber(c.text);
      return v != null && v > 0 ? v : null;
    }

    return switch (shape) {
      PanShape.none => null,
      PanShape.round => switch (n(diameter)) {
        final d? => BakingPan.round(d),
        null => null,
      },
      PanShape.rect => switch ((n(width), n(length))) {
        (final w?, final l?) => BakingPan.rect(w, l),
        _ => null,
      },
    };
  }

  void dispose() {
    diameter.dispose();
    width.dispose();
    length.dispose();
  }
}

/// "Rund Ø 26 cm" / "Eckig 20 × 30 cm".
String panLabel(BuildContext context, BakingPan pan) {
  String f(double v) => formatAmount(v, fractions: false);
  return pan.isRound
      ? context.l10n.panRoundLabel(f(pan.diameter!))
      : context.l10n.panRectLabel(f(pan.width!), f(pan.length!));
}

class PanFields extends StatelessWidget {
  const PanFields({
    super.key,
    required this.input,
    required this.onChanged,
    this.allowNone = true,
  });

  final PanInput input;
  final VoidCallback onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget field(TextEditingController c, String label) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'cm'),
        onChanged: (_) => onChanged(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        SegmentedButton<PanShape>(
          segments: [
            if (allowNone)
              ButtonSegment(value: PanShape.none, label: Text(l10n.panNone)),
            ButtonSegment(
              value: PanShape.round,
              label: Text(l10n.panRound),
              icon: const Icon(Icons.circle_outlined),
            ),
            ButtonSegment(
              value: PanShape.rect,
              label: Text(l10n.panRect),
              icon: const Icon(Icons.crop_square),
            ),
          ],
          selected: {input.shape},
          onSelectionChanged: (s) {
            input.shape = s.first;
            onChanged();
          },
        ),
        if (input.shape == PanShape.round)
          Row(children: [field(input.diameter, l10n.panDiameter)])
        else if (input.shape == PanShape.rect)
          Row(
            spacing: 12,
            children: [
              field(input.width, l10n.panWidth),
              field(input.length, l10n.panLength),
            ],
          ),
      ],
    );
  }
}
