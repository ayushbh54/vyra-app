import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/main.dart';
import 'package:vyra/services/language_service.dart';
import 'package:vyra/theme_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      ThemeManager.instance.init(),
      LanguageService.instance.init(),
    ]);
  });

  testWidgets('VyraApp boots successfully and renders initial root flow', (WidgetTester tester) async {
    await tester.pumpWidget(const VyraApp());
    await tester.pump();

    expect(find.byType(VyraApp), findsOneWidget);
  });
}
