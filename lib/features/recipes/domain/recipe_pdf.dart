import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/units/display_units.dart';
import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import 'recipe.dart';

/// Localized texts for [buildRecipePdf].
typedef PdfLabels = ({
  String ingredients,
  String steps,
  String notes,
  String Function(int servings) servings,
  String Function(int minutes) prep,
  String Function(int minutes) cook,
  String footer,
});

/// A printable A4 page (or more) for [recipe] as shown: amounts scaled to
/// [servings] (the recipe may already be converted to another tin) and in
/// [display] units, first photo on top.
Future<Uint8List> buildRecipePdf(
  Recipe recipe, {
  required PdfLabels labels,
  required Map<String, Ingredient> ingredients,
  required ByteData regularFont,
  required ByteData boldFont,
  int? servings,
  UnitDisplay display = UnitDisplay.original,
  Uint8List? photo,
}) async {
  final target = servings ?? recipe.servings;
  final regular = pw.Font.ttf(regularFont);
  final bold = pw.Font.ttf(boldFont);
  const green = PdfColor.fromInt(0xFF2E6B2E);
  final doc = pw.Document(
    title: recipe.title,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final meta = [
    labels.servings(target),
    if (recipe.prepMinutes != null) labels.prep(recipe.prepMinutes!),
    if (recipe.cookMinutes != null) labels.cook(recipe.cookMinutes!),
  ].join('  ·  ');
  String lineText(RecipeIngredient line) {
    final amount = line.amount == null
        ? null
        : scaleAmount(line.amount!, recipe.servings, target);
    final name =
        ingredients[line.ingredientId]?.name ?? line.name ?? line.rawText;
    final qty = displayQuantity(amount, line.unit, display);
    final note = line.note == null ? '' : ', ${line.note}';
    return '${[if (qty.isNotEmpty) qty, name].join(' ')}$note';
  }

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: green,
      ),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${labels.footer} · ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        if (photo != null)
          pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Image(
              pw.MemoryImage(photo),
              height: 200,
              width: double.infinity,
              fit: pw.BoxFit.cover,
            ),
          ),
        pw.SizedBox(height: photo == null ? 0 : 16),
        pw.Text(
          recipe.title,
          style: const pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          meta,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        if (recipe.ingredients.isNotEmpty) ...[
          heading(labels.ingredients),
          for (final line in recipe.ingredients)
            pw.Bullet(
              text: lineText(line),
              style: const pw.TextStyle(fontSize: 11),
            ),
        ],
        if (recipe.steps.isNotEmpty) ...[
          heading(labels.steps),
          for (final (i, step) in recipe.steps.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 22,
                    child: pw.Text(
                      '${i + 1}.',
                      style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: green,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      step.text,
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (recipe.notes.trim().isNotEmpty) ...[
          heading(labels.notes),
          pw.Text(recipe.notes.trim(), style: const pw.TextStyle(fontSize: 11)),
        ],
        if (recipe.sourceUrl != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            recipe.sourceUrl!,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
