import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// نسخة موبايل/ديسكتوب: حفظ في مجلد مؤقت ثم فتح الملف.
Future<void> saveBytesImpl(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final file = File("${dir.path}${Platform.pathSeparator}$name");
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}
