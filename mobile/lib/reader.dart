import 'package:flutter/services.dart';

import 'receipt_parser.dart';

export 'receipt_parser.dart' show TextLine;

/// Something went wrong reading a receipt. [message] is written for the
/// person using the app.
class ReadException implements Exception {
  ReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What was read from a receipt or payment screenshot.
class ReadReceipt {
  const ReadReceipt({
    this.isReceipt = true,
    this.merchant,
    this.total,
    this.currency,
    this.date,
    this.category,
    this.paymentMethod,
    this.summary,
    this.confidence = 'low',
    this.problem,
  });

  final bool isReceipt;
  final String? merchant;
  final double? total;
  final String? currency;
  final DateTime? date;
  final String? category;
  final String? paymentMethod;
  final String? summary;
  final String confidence;
  final String? problem;

  /// Safe to save without asking the person anything.
  bool get confident => isReceipt && (total ?? 0) > 0 && confidence != 'low';
}

abstract class ReceiptReader {
  Future<ReadReceipt> read(Uint8List image, {List<String> categories = const []});
}

/// Finds the text in an image, on the phone itself.
abstract class TextRecognizer {
  Future<List<TextLine>> read(Uint8List image);
}

/// Apple's built-in text recognition (the same one Photos and Live Text use),
/// via a small bridge in `ios/Runner/AppDelegate.swift`. Reads English and
/// Chinese, works in flight mode, and sends nothing anywhere.
class VisionTextRecognizer implements TextRecognizer {
  static const _channel = MethodChannel('spendsnap/text');

  @override
  Future<List<TextLine>> read(Uint8List image) async {
    final List<Object?>? raw;
    try {
      raw = await _channel.invokeListMethod<Object?>('read', image);
    } on MissingPluginException {
      throw ReadException("This phone can't read receipts yet. Type the amount in.");
    } on PlatformException {
      throw ReadException("Couldn't read this picture. Type the amount in.");
    }
    return [
      for (final r in raw ?? const [])
        if (r is Map) TextLine('${r['text'] ?? ''}', (r['height'] as num?)?.toDouble() ?? 0),
    ];
  }
}

/// Reads receipts and payment screenshots without the internet: the phone
/// finds the text, then [parseReceipt] picks out the amount, shop and date.
class OfflineReader implements ReceiptReader {
  OfflineReader([TextRecognizer? text]) : _text = text ?? VisionTextRecognizer();
  final TextRecognizer _text;

  @override
  Future<ReadReceipt> read(Uint8List image, {List<String> categories = const []}) async =>
      parseReceipt(await _text.read(image), categories: categories);
}
