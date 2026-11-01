import 'package:image_picker/image_picker.dart' as ip;

import 'app.dart';

/// The real camera and photo library.
class DevicePicker implements ReceiptPicker {
  final _p = ip.ImagePicker();

  Future<PickedImage?> _pick(ip.ImageSource source) async {
    // Shrinking on the phone makes uploads fast on mobile data; the server
    // doesn't need more than about 1600 px to read a receipt.
    final f = await _p.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (f == null) return null;
    return PickedImage(await f.readAsBytes(), f.name);
  }

  @override
  Future<PickedImage?> camera() => _pick(ip.ImageSource.camera);

  @override
  Future<PickedImage?> gallery() => _pick(ip.ImageSource.gallery);
}
