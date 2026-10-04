import 'package:flutter_test/flutter_test.dart';
import 'package:watch_tester/main.dart';

void main() {
  testWidgets('WatchProberApp boots and renders prober dashboard UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const WatchProberApp());
    await tester.pump();

    // Verify app booted
    expect(find.byType(WatchProberApp), findsOneWidget);
    expect(find.text('VYRA WATCH PROBER'), findsOneWidget);
    expect(find.text('⚡ 2. PROTOCOL COMBINATIONS'), findsOneWidget);
    expect(find.text('Run All (8)'), findsOneWidget);
  });
}
