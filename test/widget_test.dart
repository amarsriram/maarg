import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maarg/app/app.dart';

void main() {
  testWidgets('Maarg app smoke test - verify login screen load', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaargApp(),
      ),
    );

    // Verify that the login screen loads and displays the app name
    expect(find.text('MAARG'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
