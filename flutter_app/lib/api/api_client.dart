import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../main.dart';

/// عميل HTTP موحّد: Bearer token + تجديد تلقائي مرة واحدة عند 401.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  static const _storage = FlutterSecureStorage();
  static const _kAccess = "access_token";
  static const _kRefresh = "refresh_token";

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {"Accept": "application/json"},
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  bool _refreshing = false;
  final List<void Function(String)> _onForceLogoutListeners = [];

  void onForceLogout(void Function(String) cb) => _onForceLogoutListeners.add(cb);

  Future<void> initInterceptors() async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await _storage.read(key: _kAccess);
          if (access != null && access.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $access";
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // انتهى الـ access token؟ جرّب refresh مرة واحدة وأعد الطلب الأصلي.
          if (e.response?.statusCode == 401 &&
              e.requestOptions.extra["retried"] != true &&
              !_refreshing) {
            _refreshing = true;
            try {
              final refreshed = await _tryRefresh();
              _refreshing = false;
              if (refreshed) {
                final opts = e.requestOptions;
                opts.extra["retried"] = true;
                final access = await _storage.read(key: _kAccess);
                opts.headers["Authorization"] = "Bearer $access";
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              }
              await logout();
              for (final cb in _onForceLogoutListeners) {
                cb("انتهت الجلسة، سجّل الدخول من جديد.");
              }
            } catch (_) {
              _refreshing = false;
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: _kRefresh);
    if (refresh == null || refresh.isEmpty) return false;
    final res = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).post(
      "/api/token/refresh/",
      data: {"refresh": refresh},
    );
    if (res.statusCode == 200) {
      await _storage.write(key: _kAccess, value: res.data["access"]);
      if (res.data["refresh"] != null) {
        await _storage.write(key: _kRefresh, value: res.data["refresh"]);
      }
      return true;
    }
    return false;
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> logout() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  /// استخراج رسالة الخطأ من رد الـ API (detail أو errors).
  static String extractError(dynamic data) {
    if (data is Map) {
      if (data["detail"] is String) return data["detail"];
      final errors = data["errors"];
      if (errors is Map && errors.isNotEmpty) {
        final buf = StringBuffer();
        errors.forEach((k, v) {
          buf.writeln("$k: ${_flatten(v)}");
        });
        return buf.toString().trim();
      }
    }
    return "حدث خطأ غير متوقع.";
  }

  /// نسخة للـ exceptions (DioException فيها response.data).
  static String extractErrorFromException(Object e) {
    if (e is DioException) {
      return extractError(e.response?.data);
    }
    return e.toString();
  }

  static String _flatten(dynamic v) {
    if (v is List) return v.map(_flatten).join(" ");
    if (v is Map) return v.values.map(_flatten).join(" ");
    return v.toString();
  }
}
