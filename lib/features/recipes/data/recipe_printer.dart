import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Android print dialog (also "Als PDF speichern") and PDF sharing; behind
/// an interface so tests don't open system dialogs.
abstract class RecipePrinter {
  Future<void> print(Uint8List pdf, String name);
  Future<void> share(Uint8List pdf, String fileName);
}

class SystemRecipePrinter implements RecipePrinter {
  const SystemRecipePrinter();

  @override
  Future<void> print(Uint8List pdf, String name) =>
      Printing.layoutPdf(onLayout: (_) async => pdf, name: name);

  @override
  Future<void> share(Uint8List pdf, String fileName) =>
      Printing.sharePdf(bytes: pdf, filename: fileName);
}
