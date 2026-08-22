import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../main.dart';
import 'api_client.dart';
import 'saver_stub.dart'
    if (dart.library.html) "saver_web.dart"
    if (dart.library.io) "saver_io.dart";

String _fmt(DateTime d) =>
    "${d.year.toString().padLeft(4, "0")}-"
    "${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

class ReportsRepository {
  /// التقرير اليومي كـ JSON (مدير فقط)
  Future<Map<String, dynamic>> daily(DateTime date) async {
    final res = await ApiClient.instance.dio.get("/api/reports/daily/${_fmt(date)}/");
    if (res.statusCode != 200) throw Exception(ApiClient.extractError(res.data));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Uint8List> _download(String path, Map<String, dynamic>? query) async {
    final access = await const FlutterSecureStorage().read(key: "access_token");
    final res = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).get(
      path,
      queryParameters: query,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {"Authorization": "Bearer ${access ?? ''}"},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode != 200) {
      throw Exception("فشل التحميل (${res.statusCode}).");
    }
    return Uint8List.fromList(List<int>.from(res.data));
  }

  Future<void> downloadDailyPdf(DateTime date) async {
    final bytes = await _download("/report/pdf/${_fmt(date)}/", null);
    await saveBytesImpl(bytes, "daily_report_${_fmt(date)}.pdf");
  }

  Future<void> downloadExcel(DateTime from, DateTime to, String? unit) async {
    final bytes = await _download("/records/export/", {
      "from": _fmt(from),
      "to": _fmt(to),
      if (unit != null && unit.isNotEmpty) "unit": unit,
    });
    await saveBytesImpl(bytes, "records_${_fmt(from)}_${_fmt(to)}.xlsx");
  }
}
