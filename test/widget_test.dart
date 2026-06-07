// ============================================================
// OmniLight by Abstrackt
// Файл: widget_test.dart
// Назначение: Базовые smoke-тесты для OmniLightApp.
//             Проверяют корректность инициализации провайдеров
//             и отображение заголовка приложения.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omnilight/core/localization_theme_store.dart';
import 'package:omnilight/core/device_manager.dart';
import 'package:omnilight/main.dart';

void main() {
  // ─────────────────────────────────────────────
  // Smoke-тест: заголовок OmniLight отображается
  // ─────────────────────────────────────────────
  testWidgets('OmniLight заголовок отображается на главном экране',
      (WidgetTester tester) async {
    // Инициализируем провайдеры (без shared_preferences и BLE в тестах)
    final themeStore = LocalizationThemeStore();
    final deviceManager = DeviceManager();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocalizationThemeStore>.value(
            value: themeStore,
          ),
          ChangeNotifierProvider<DeviceManager>.value(
            value: deviceManager,
          ),
        ],
        child: const OmniLightApp(),
      ),
    );

    // Проверяем наличие текста «OmniLight» в дереве виджетов
    expect(find.text('OmniLight'), findsWidgets);

    // Проверяем наличие подзаголовка «by Abstrackt»
    expect(find.text('by Abstrackt'), findsOneWidget);
  });
}
