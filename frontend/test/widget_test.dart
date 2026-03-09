import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HideNSeekApp());
    await tester.pump();
    // Verify the splash screen title text is present
    expect(find.text('HIDE N SEEK'), findsOneWidget);
  });
}
