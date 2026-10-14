import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_app/main.dart';

void main() {
  testWidgets('Warehouse app starts without login', (tester) async {
    await tester.pumpWidget(const WarehouseApp());

    expect(find.text('الرئيسية'), findsOneWidget);
  });
}
