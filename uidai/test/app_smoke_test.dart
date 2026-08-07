import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('material app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('UIDAI Capture Pipeline')),
        ),
      ),
    );

    expect(find.text('UIDAI Capture Pipeline'), findsOneWidget);
  });
}
