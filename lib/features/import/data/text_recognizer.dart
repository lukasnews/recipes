import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR for printed text. Works offline.
abstract class TextRecognizerService {
  Future<String> recognize(String imagePath);
}

class MlKitTextRecognizer implements TextRecognizerService {
  @override
  Future<String> recognize(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
