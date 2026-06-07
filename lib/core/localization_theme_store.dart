// ============================================================
// OmniLight by Abstrackt
// Файл: localization_theme_store.dart
// Назначение: Хранилище состояния для управления темой приложения
//             и языком интерфейса (EN / RU / UA).
//             Использует ChangeNotifier + shared_preferences для
//             персистентного сохранения пользовательских настроек.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Перечисление: доступные языки интерфейса
// ─────────────────────────────────────────────
enum AppLanguage {
  en, // Английский
  ru, // Русский
  ua, // Украинский
}

// ─────────────────────────────────────────────
// Перечисление: доступные визуальные темы
// ─────────────────────────────────────────────
enum AppTheme {
  light,    // Светлая тема
  dark,     // Тёмная тема
  cyberNeon, // Кибер-неоновая тема
}

// ─────────────────────────────────────────────
// Глобальная карта локализованных строк
// Ключ — строковый идентификатор UI-элемента,
// значение — Map<AppLanguage, String>
// ─────────────────────────────────────────────
const Map<String, Map<AppLanguage, String>> _strings = {
  // ── Общие заголовки ──
  'app_title': {
    AppLanguage.en: 'OmniLight',
    AppLanguage.ru: 'OmniLight',
    AppLanguage.ua: 'OmniLight',
  },
  'app_subtitle': {
    AppLanguage.en: 'by Abstrackt',
    AppLanguage.ru: 'by Abstrackt',
    AppLanguage.ua: 'by Abstrackt',
  },

  // ── Статус подключения ──
  'status_disconnected': {
    AppLanguage.en: 'Disconnected',
    AppLanguage.ru: 'Отключено',
    AppLanguage.ua: 'Відключено',
  },
  'status_scanning': {
    AppLanguage.en: 'Scanning…',
    AppLanguage.ru: 'Сканирование…',
    AppLanguage.ua: 'Сканування…',
  },
  'status_connected': {
    AppLanguage.en: 'Connected to',
    AppLanguage.ru: 'Подключено к',
    AppLanguage.ua: 'Підключено до',
  },
  'status_connecting': {
    AppLanguage.en: 'Connecting…',
    AppLanguage.ru: 'Подключение…',
    AppLanguage.ua: 'Підключення…',
  },
  'status_error': {
    AppLanguage.en: 'Connection error',
    AppLanguage.ru: 'Ошибка подключения',
    AppLanguage.ua: 'Помилка підключення',
  },

  // ── Кнопки управления ──
  'btn_scan': {
    AppLanguage.en: 'Scan',
    AppLanguage.ru: 'Сканировать',
    AppLanguage.ua: 'Сканувати',
  },
  'btn_disconnect': {
    AppLanguage.en: 'Disconnect',
    AppLanguage.ru: 'Отключить',
    AppLanguage.ua: 'Відключити',
  },
  'btn_turn_on': {
    AppLanguage.en: 'Turn ON',
    AppLanguage.ru: 'Включить',
    AppLanguage.ua: 'Увімкнути',
  },
  'btn_turn_off': {
    AppLanguage.en: 'Turn OFF',
    AppLanguage.ru: 'Выключить',
    AppLanguage.ua: 'Вимкнути',
  },
  'btn_settings': {
    AppLanguage.en: 'Settings',
    AppLanguage.ru: 'Настройки',
    AppLanguage.ua: 'Налаштування',
  },
  'support_title': {
    AppLanguage.en: 'Support & FAQ',
    AppLanguage.ru: 'Поддержка и FAQ',
    AppLanguage.ua: 'Підтримка та FAQ',
  },

  // ── Пресеты цветов ──
  'preset_red': {
    AppLanguage.en: 'Red',
    AppLanguage.ru: 'Красный',
    AppLanguage.ua: 'Червоний',
  },
  'preset_green': {
    AppLanguage.en: 'Green',
    AppLanguage.ru: 'Зелёный',
    AppLanguage.ua: 'Зелений',
  },
  'preset_blue': {
    AppLanguage.en: 'Blue',
    AppLanguage.ru: 'Синий',
    AppLanguage.ua: 'Синій',
  },
  'preset_white': {
    AppLanguage.en: 'White',
    AppLanguage.ru: 'Белый',
    AppLanguage.ua: 'Білий',
  },
  'preset_warm': {
    AppLanguage.en: 'Warm',
    AppLanguage.ru: 'Тёплый',
    AppLanguage.ua: 'Теплий',
  },

  // ── Настройки ──
  'settings_title': {
    AppLanguage.en: 'Settings',
    AppLanguage.ru: 'Настройки',
    AppLanguage.ua: 'Налаштування',
  },
  'settings_language': {
    AppLanguage.en: 'Language',
    AppLanguage.ru: 'Язык',
    AppLanguage.ua: 'Мова',
  },
  'settings_theme': {
    AppLanguage.en: 'Theme',
    AppLanguage.ru: 'Тема',
    AppLanguage.ua: 'Тема',
  },
  'theme_light': {
    AppLanguage.en: 'Light',
    AppLanguage.ru: 'Светлая',
    AppLanguage.ua: 'Світла',
  },
  'theme_dark': {
    AppLanguage.en: 'Dark',
    AppLanguage.ru: 'Тёмная',
    AppLanguage.ua: 'Темна',
  },
  'theme_cyber': {
    AppLanguage.en: 'Cyber Neon',
    AppLanguage.ru: 'Кибер-неон',
    AppLanguage.ua: 'Кібер-неон',
  },

  // ── Яркость ──
  'brightness_label': {
    AppLanguage.en: 'Brightness',
    AppLanguage.ru: 'Яркость',
    AppLanguage.ua: 'Яскравість',
  },

  // ── Цветовой пикер ──
  'color_picker_label': {
    AppLanguage.en: 'Color',
    AppLanguage.ru: 'Цвет',
    AppLanguage.ua: 'Колір',
  },

  // ── Устройства ──
  'no_devices_found': {
    AppLanguage.en: 'No devices found',
    AppLanguage.ru: 'Устройства не найдены',
    AppLanguage.ua: 'Пристрої не знайдено',
  },
  'select_device': {
    AppLanguage.en: 'Select a device',
    AppLanguage.ru: 'Выберите устройство',
    AppLanguage.ua: 'Оберіть пристрій',
  },

  // ── Разрешения BLE ──
  'ble_permission_denied': {
    AppLanguage.en: 'Bluetooth permission denied. Please enable in Settings.',
    AppLanguage.ru: 'Доступ к Bluetooth запрещён. Включите в настройках.',
    AppLanguage.ua: 'Доступ до Bluetooth заборонено. Увімкніть у налаштуваннях.',
  },
  'ble_unavailable': {
    AppLanguage.en: 'Bluetooth is not available on this device.',
    AppLanguage.ru: 'Bluetooth недоступен на этом устройстве.',
    AppLanguage.ua: 'Bluetooth недоступний на цьому пристрої.',
  },
  'ble_off': {
    AppLanguage.en: 'Bluetooth is turned off. Please enable it.',
    AppLanguage.ru: 'Bluetooth выключен. Пожалуйста, включите его.',
    AppLanguage.ua: 'Bluetooth вимкнено. Будь ласка, увімкніть його.',
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Класс: AppThemeData
// Назначение: Хранит ThemeData и вспомогательные цвета для каждой темы.
//             Кастомные неоновые цвета не входят в стандартный ThemeData,
//             поэтому они хранятся отдельно в полях этого класса.
// ─────────────────────────────────────────────────────────────────────────────
class AppThemeData {
  final ThemeData themeData;
  final Color accentPrimary;   // Главный акцентный цвет
  final Color accentSecondary; // Вторичный акцентный цвет
  final Color cardColor;       // Цвет карточек/плашек
  final Color surfaceColor;    // Цвет поверхности (фон элементов)
  final Color glowColor;       // Цвет свечения (используется в Cyber Neon)
  final bool hasGlow;          // Включён ли эффект свечения

  const AppThemeData({
    required this.themeData,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.cardColor,
    required this.surfaceColor,
    required this.glowColor,
    required this.hasGlow,
  });
}

// Фабрика тем: создаёт AppThemeData для каждого режима
AppThemeData buildThemeData(AppTheme theme) {
  switch (theme) {
    // ─────────────────────────────
    // Светлая тема
    // ─────────────────────────────
    case AppTheme.light:
      return AppThemeData(
        themeData: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),    // Чистый синий акцент
            secondary: Color(0xFF0EA5E9),
            surface: Color(0xFFFFFFFF),
            onSurface: Color(0xFF1E293B),  // Тёмный сланцевый текст
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: Color(0xFF1E293B),
            elevation: 0,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: TextStyle(color: Color(0xFF475569)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
        ),
        accentPrimary: const Color(0xFF2563EB),
        accentSecondary: const Color(0xFF0EA5E9),
        cardColor: const Color(0xFFFFFFFF),
        surfaceColor: const Color(0xFFF1F5F9),
        glowColor: Colors.transparent,
        hasGlow: false,
      );

    // ─────────────────────────────
    // Тёмная тема
    // ─────────────────────────────
    case AppTheme.dark:
      return AppThemeData(
        themeData: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A), // Deep charcoal
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF60A5FA),    // Современный серебристо-синий
            secondary: Color(0xFF94A3B8),
            surface: Color(0xFF1E293B),
            onSurface: Color(0xFFF1F5F9),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F172A),
            foregroundColor: Color(0xFFF1F5F9),
            elevation: 0,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: Color(0xFFF1F5F9),
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF60A5FA),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
        ),
        accentPrimary: const Color(0xFF60A5FA),
        accentSecondary: const Color(0xFF94A3B8),
        cardColor: const Color(0xFF1E293B),
        surfaceColor: const Color(0xFF0F172A),
        glowColor: Colors.transparent,
        hasGlow: false,
      );

    // ─────────────────────────────
    // Кибер-неоновая тема
    // ─────────────────────────────
    case AppTheme.cyberNeon:
      return AppThemeData(
        themeData: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050505), // Obsidian black
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF00D6),    // Неоновый пурпурный
            secondary: Color(0xFF00F0FF),  // Неоновый цианый
            surface: Color(0xFF0D0D0D),
            onSurface: Color(0xFFEEEEEE),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF050505),
            foregroundColor: Color(0xFFFF00D6),
            elevation: 0,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: Color(0xFFFF00D6),
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(color: Color(0xFFFF00D6), blurRadius: 8),
              ],
            ),
            bodyMedium: TextStyle(color: Color(0xFF00F0FF)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFFFF00D6),
              side: const BorderSide(color: Color(0xFFFF00D6), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
        ),
        accentPrimary: const Color(0xFFFF00D6),   // Пурпурный
        accentSecondary: const Color(0xFF00F0FF), // Цианый
        cardColor: const Color(0xFF0D0D0D),
        surfaceColor: const Color(0xFF050505),
        glowColor: const Color(0xFFFF00D6),
        hasGlow: true,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Класс: LocalizationThemeStore
// Назначение: ChangeNotifier-провайдер для управления активной темой и языком.
//             Все настройки сохраняются через shared_preferences и
//             восстанавливаются при следующем запуске приложения.
// ─────────────────────────────────────────────────────────────────────────────
class LocalizationThemeStore extends ChangeNotifier {
  // ── Текущие значения ──
  AppLanguage _language = AppLanguage.en;
  AppTheme _appTheme = AppTheme.dark;

  // ── Ключи для shared_preferences ──
  static const String _keyLanguage = 'omnilight_language';
  static const String _keyTheme = 'omnilight_theme';

  // ── Геттеры ──
  AppLanguage get language => _language;
  AppTheme get appTheme => _appTheme;

  /// Возвращает собранный объект ThemeData + кастомные цвета для текущей темы.
  AppThemeData get currentThemeData => buildThemeData(_appTheme);

  /// Возвращает локализованную строку по ключу.
  /// Если ключ не найден — возвращает сам ключ (безопасный fallback).
  String tr(String key) {
    final map = _strings[key];
    if (map == null) return key;
    return map[_language] ?? map[AppLanguage.en] ?? key;
  }

  // ─────────────────────────────────────────────
  // Инициализация: загрузка сохранённых настроек
  // ─────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Восстанавливаем язык
    final langIndex = prefs.getInt(_keyLanguage);
    if (langIndex != null && langIndex < AppLanguage.values.length) {
      _language = AppLanguage.values[langIndex];
    }

    // Восстанавливаем тему
    final themeIndex = prefs.getInt(_keyTheme);
    if (themeIndex != null && themeIndex < AppTheme.values.length) {
      _appTheme = AppTheme.values[themeIndex];
    }

    // Уведомляем слушателей после загрузки
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Смена языка интерфейса
  // ─────────────────────────────────────────────
  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLanguage, lang.index);
  }

  // ─────────────────────────────────────────────
  // Смена темы приложения
  // ─────────────────────────────────────────────
  Future<void> setTheme(AppTheme theme) async {
    if (_appTheme == theme) return;
    _appTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, theme.index);
  }
}
