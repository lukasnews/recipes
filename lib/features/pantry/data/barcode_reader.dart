import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Reads a product barcode (EAN/UPC) from a photo. On-device, offline.
abstract class BarcodeReader {
  Future<String?> read(String imagePath);
}

class MlKitBarcodeReader implements BarcodeReader {
  @override
  Future<String?> read(String imagePath) async {
    final scanner = BarcodeScanner(
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upca,
        BarcodeFormat.upce,
      ],
    );
    try {
      final codes = await scanner.processImage(
        InputImage.fromFilePath(imagePath),
      );
      for (final c in codes) {
        final v = c.rawValue;
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }
}
