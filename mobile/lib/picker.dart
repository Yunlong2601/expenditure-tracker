import 'package:image_picker/image_picker.dart' as ip;

import 'app.dart';

/// The real camera and photo library.
class DevicePicker implements ReceiptPicker {
  final _p = ip.ImagePicker();

  Future<PickedImage?> _pick(ip.ImageSource source) async {
    // Big enough for the phone to read small print, small enough that a year
    // of receipt photos doesn't fill the phone.
    final f = await _p.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (f == null) return null;
    return PickedImage(await f.readAsBytes(), f.name);
  }

  @override
  Future<PickedImage?> camera() => _pick(ip.ImageSource.camera);

  @override
  Future<PickedImage?> gallery() => _pick(ip.ImageSource.gallery);
}
