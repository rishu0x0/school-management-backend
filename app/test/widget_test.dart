import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_attendance/app.dart';

void main() {
  testWidgets('App smoke test — renders without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // Just verify the widget tree builds without error.
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
