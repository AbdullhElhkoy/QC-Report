import 'package:flutter/material.dart';

/// عرض أي قيمة (scalar / Map / List) بشكل متداخل من غير فقد أي بيانات.
/// مستخدم في شاشات التقارير (اليومي + الوردية) لعرض قسم كامل من الـ JSON.

bool _isEmptyValue(dynamic value) {
  if (value == null) return true;
  if (value is Map) return value.isEmpty;
  if (value is List) return value.isEmpty;
  if (value is String) return value.isEmpty;
  return false;
}

/// صف واحد key: value بسيط، مع إزاحة حسب العمق.
Widget _kvRow(String label, dynamic value, int depth) {
  return Padding(
    padding: EdgeInsets.only(right: depth * 12.0, top: 3, bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text("$value",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

/// صندوق فرعي بعنوان وحدود خفيفة، عشان يبقى واضح بصريًا إن دول عناصر
/// تابعة لبعضها (زي products > S.B > product_type/exp/dom...) بدل ما يبانوا
/// سطور متتالية مالهاش علاقة ببعض.
Widget _groupBox(String label, List<Widget> children, int depth) {
  return Container(
    margin: EdgeInsets.only(right: depth * 10.0, top: 6, bottom: 2),
    padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4, left: 4),
    decoration: BoxDecoration(
      border: Border(
        right: BorderSide(color: Colors.blueGrey.shade200, width: 2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
        const SizedBox(height: 2),
        ...children,
      ],
    ),
  );
}

/// عرض أي قيمة (scalar / Map / List) بشكل متداخل.
List<Widget> _renderNode(String label, dynamic value, int depth) {
  if (_isEmptyValue(value)) {
    return [_kvRow(label, "—", depth)];
  }

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final children = [
      for (final e in map.entries) ..._renderNode(e.key, e.value, 1),
    ];
    return [_groupBox(label, children, depth)];
  }

  if (value is List) {
    if (value.every((e) => e is num || e is String || e is bool)) {
      return [_kvRow(label, value.join("، "), depth)];
    }
    final children = <Widget>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final itemLabel = (map["label"] ??
                map["name"] ??
                map["product_type"] ??
                map["unit"])
                ?.toString() ??
            "#${i + 1}";
        final itemChildren = [
          for (final e in map.entries)
            if (e.key != "label" && e.key != "name")
              ..._renderNode(e.key, e.value, 1),
        ];
        children.add(_groupBox(itemLabel, itemChildren, 1));
      } else {
        children.add(_kvRow("#${i + 1}", item, 1));
      }
    }
    return [_groupBox(label, children, depth)];
  }

  return [_kvRow(label, value, depth)];
}

/// قسم كامل من التقرير كـ Card: يعرض الـ Map/List كاملًا من غير فقد.
Widget reportSection(String title, dynamic data) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          if (_isEmptyValue(data))
            const Text("— لا توجد بيانات —",
                style: TextStyle(color: Colors.grey))
          else if (data is Map)
            for (final e in Map<String, dynamic>.from(data).entries)
              ..._renderNode(e.key, e.value, 0)
          else if (data is List)
            for (var i = 0; i < data.length; i++)
              ..._renderNode("#${i + 1}", data[i], 0)
          else
            Text("$data"),
        ],
      ),
    ),
  );
}