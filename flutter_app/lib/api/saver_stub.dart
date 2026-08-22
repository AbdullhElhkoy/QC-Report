import 'dart:typed_data';

/// نسخة احتياطية للمنصات غير المدعومة.
Future<void> saveBytesImpl(Uint8List bytes, String name) async {
  throw UnsupportedError("حفظ الملفات غير مدعوم على هذه المنصة.");
}
