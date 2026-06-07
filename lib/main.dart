// ============================================================
// OmniLight by Abstrackt
// Файл: main.dart
// Назначение: Точка входа приложения.
//             Инициализирует провайдеры состояния, применяет тему
//             и передаёт управление главному экрану.
//
// ── iOS Info.plist — необходимые ключи Bluetooth ──────────────
//
// Добавьте следующие ключи в ios/Runner/Info.plist:
//
// <!-- Описание использования Bluetooth (ОБЯЗАТЕЛЬНО для App Store) -->
// <key>NSBluetoothAlwaysUsageDescription</key>
// <string>OmniLight использует Bluetooth для управления LED-лентой.</string>
//
// <!-- Для совместимости с iOS 12 и старше -->
// <key>NSBluetoothPeripheralUsageDescription</key>
// <string>OmniLight использует Bluetooth для управления LED-лентой.</string>
//
// Без этих ключей iOS отклонит запрос разрешения и приложение
// не сможет сканировать BLE-устройства.
// ─────────────────────────────────────────────────────────────
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/localization_theme_store.dart';
import 'core/device_manager.dart';
import 'screens/main_screen.dart';

void main() async {
  // Гарантируем инициализацию Flutter-биндингов до первого await
  WidgetsFlutterBinding.ensureInitialized();

  // Разрешаем только портретную ориентацию (стандарт для iOS-приложений управления)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Инициализируем хранилище тем/языка из shared_preferences
  final themeStore = LocalizationThemeStore();
  await themeStore.init();

  // Инициализируем менеджер устройств (подписывается на BLE-адаптер)
  final deviceManager = DeviceManager();
  await deviceManager.init();

  runApp(
    // MultiProvider — корневой провайдер всего дерева виджетов
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: OmniLightApp
// Назначение: Корневой MaterialApp, реагирует на изменения темы/языка
//             через Consumer и перестраивает дерево при их смене.
// ─────────────────────────────────────────────────────────────────────────────
class OmniLightApp extends StatelessWidget {
  const OmniLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer реагирует на notifyListeners() из LocalizationThemeStore
    return Consumer<LocalizationThemeStore>(
      builder: (context, store, _) {
        final themeData = store.currentThemeData;
        return MaterialApp(
          title: 'OmniLight by Abstrackt',
          debugShowCheckedModeBanner: false,
          theme: themeData.themeData,
          home: const MainScreen(),
        );
      },
    );
  }
}
