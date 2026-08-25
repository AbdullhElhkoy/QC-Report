import 'package:flutter_test/flutter_test.dart';

import 'package:qc_report_app/main.dart';

void main() {
  testWidgets('app boots to bootstrap screen', (WidgetTester tester) async {
    await tester.pumpWidget(const QcReportApp());
    await tester.pump();
    expect(find.byType(QcReportApp), findsOneWidget);
  });
}
