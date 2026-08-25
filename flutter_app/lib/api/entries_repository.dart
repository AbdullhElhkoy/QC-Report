import 'api_client.dart';

/// مستودع الإدخالات: كل وحدة ليها دالة تبني الـ body الصحيح وتنبط على endpoint الصح.
class EntriesRepository {
  dynamic _err(dynamic res) => throw Exception(ApiClient.extractError(res.data));

  /// SOP: SOP_A..D / G_SOP / C_PACKING
  /// rows: {"S_B": {"exp":..,"dom":..,"std":..,"nc":..,"cause":..,"note":..}, ...}
  Future<void> createSop(String unit, Map<String, Map<String, dynamic>> rows,
      {Map<String, dynamic>? bulkLog, String generalNotes = ""}) async {
    final res = await ApiClient.instance.dio.post(
      "/api/entries/sop/$unit/",
      data: {
        "general_notes": generalNotes,
        "rows": rows,
        if (bulkLog != null) "bulk_log": bulkLog,
      },
    );
    if (res.statusCode != 201) _err(res);
  }

  /// GCC1/GCC2
  Future<void> createGcc(String unit, Map<String, Map<String, dynamic>> colors,
      {required num sb, required num nc}) async {
    final res = await ApiClient.instance.dio.post(
      "/api/entries/gcc/$unit/",
      data: {"general_notes": "", "colors": colors, "sb": sb, "nc": nc},
    );
    if (res.statusCode != 201) _err(res);
  }

  /// LOADING: {"SOP": {"exp":..,"dom":..}, ...}
  Future<void> createLoading(Map<String, Map<String, dynamic>> rows) async {
    final res = await ApiClient.instance.dio.post(
      "/api/entries/loading/",
      data: {"general_notes": "", "rows": rows},
    );
    if (res.statusCode != 201) _err(res);
  }

  /// DCP
  Future<void> createDcp({
    required Map<String, dynamic> bb,
    required Map<String, dynamic> sb,
    required Map<String, dynamic> asRow,
    required Map<String, dynamic> tests,
    required List<Map<String, dynamic>> whiteReasons,
    required List<Map<String, dynamic>> ncReasons,
  }) async {
    final res = await ApiClient.instance.dio.post(
      "/api/entries/dcp/",
      data: {
        "general_notes": "",
        "bb": bb,
        "sb": sb,
        "as_row": asRow,
        "tests": tests,
        "white_reasons": whiteReasons,
        "nc_reasons": ncReasons,
      },
    );
    if (res.statusCode != 201) _err(res);
  }

  /// PA / SA
  Future<void> createPacking(String unit, Map<String, num> valuesByTypeId) async {
    final res = await ApiClient.instance.dio.post(
      "/api/entries/packing/$unit/",
      data: {
        "general_notes": "",
        "values": valuesByTypeId.map((k, v) => MapEntry(k, v)),
      },
    );
    if (res.statusCode != 201) _err(res);
  }

  // ---- Lookups ----

  Future<List<Map<String, dynamic>>> dcpReasons(String category) async {
    final res = await ApiClient.instance.dio.get("/api/dcp-reasons/");
    return [
      for (final r in (res.data[category] as List))
        {"id": r["id"], "name": r["name"]}
    ];
  }

  Future<List<Map<String, dynamic>>> packingTypes(String factory) async {
    final res = await ApiClient.instance.dio.get("/api/packing-types/$factory/");
    return [
      for (final t in (res.data["types"] as List))
        {"id": t["id"], "name": t["name"]}
    ];
  }
}