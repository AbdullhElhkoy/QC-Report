import 'api_client.dart';

/// بيانات المستخدم من /api/me/
class UserModel {
  final String username;
  final String fullName;
  final bool isManager;
  final String? assignedUnit;
  final String? assignedUnitLabel;

  UserModel({
    required this.username,
    required this.fullName,
    required this.isManager,
    this.assignedUnit,
    this.assignedUnitLabel,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        username: j["username"] ?? "",
        fullName: j["full_name"] ?? "",
        isManager: j["is_manager"] == true,
        assignedUnit: j["assigned_unit"],
        assignedUnitLabel: j["assigned_unit_label"],
      );
}

/// حالة الوردية لوحدة معينة
class EntryStatus {
  final String unit;
  final String unitLabel;
  final String date;
  final String? nextShift;
  final bool allShiftsDoneToday;

  EntryStatus({
    required this.unit,
    required this.unitLabel,
    required this.date,
    required this.nextShift,
    required this.allShiftsDoneToday,
  });

  factory EntryStatus.fromJson(Map<String, dynamic> j) => EntryStatus(
        unit: j["unit"],
        unitLabel: j["unit_label"],
        date: j["date"],
        nextShift: j["next_shift"],
        allShiftsDoneToday: j["all_shifts_done_today"] == true,
      );

  String get shiftLabel {
    switch (nextShift) {
      case "SHIFT_1":
        return "الوردية الأولى";
      case "SHIFT_2":
        return "الوردية الثانية";
      case "SHIFT_3":
        return "الوردية الثالثة";
      default:
        return "-";
    }
  }
}

class UnitItem {
  final String value;
  final String label;
  UnitItem({required this.value, required this.label});

  factory UnitItem.fromJson(Map<String, dynamic> j) =>
      UnitItem(value: j["value"], label: j["label"]);
}

class AuthRepository {
  Future<String?> readAccessToken() => ApiClient.instance.readAccessToken();

  Future<UserModel> login(String username, String password) async {
    final res = await ApiClient.instance.dio.post(
      "/api/token/",
      data: {"username": username, "password": password},
    );
    if (res.statusCode != 200) {
      throw Exception("بيانات الدخول غير صحيحة.");
    }
    await ApiClient.instance.saveTokens(
      access: res.data["access"],
      refresh: res.data["refresh"],
    );
    return me();
  }

  Future<UserModel> me() async {
    final res = await ApiClient.instance.dio.get("/api/me/");
    if (res.statusCode != 200) throw Exception("فشل تحميل بيانات المستخدم.");
    return UserModel.fromJson(res.data);
  }

  Future<List<UnitItem>> units() async {
    final res = await ApiClient.instance.dio.get("/api/units/");
    return [
      for (final u in (res.data["units"] as List)) UnitItem.fromJson(u)
    ];
  }

  Future<EntryStatus> entryStatus(String unit) async {
    final res = await ApiClient.instance.dio.get("/api/entry-status/$unit/");
    if (res.statusCode == 403) {
      throw Exception("لا تملك صلاحية الوصول لهذه الوحدة.");
    }
    return EntryStatus.fromJson(res.data);
  }

  Future<void> logout() => ApiClient.instance.logout();
}
