import 'package:flutter/material.dart';

class AppBanner {
  final String id;
  final Map<String, String> titles;
  final Map<String, String> descriptions;
  final Map<String, String> slogans;
  final List<Color> gradientColors;

  const AppBanner({
    required this.id,
    required this.titles,
    required this.descriptions,
    required this.slogans,
    required this.gradientColors,
  });

  String getTitle(String langCode) => titles[langCode] ?? titles['en']!;
  String getDescription(String langCode) => descriptions[langCode] ?? descriptions['en']!;
  String getSlogan(String langCode) => slogans[langCode] ?? slogans['en']!;
}

const List<AppBanner> appBanners = [
  AppBanner(
    id: 'premium_pro',
    titles: {
      'en': 'OmniLight Pro',
      'ru': 'OmniLight Pro',
      'ua': 'OmniLight Pro',
    },
    descriptions: {
      'en': 'Unlock all features and exclusive effects.',
      'ru': 'Разблокируйте все функции и эксклюзивные эффекты.',
      'ua': 'Розблокуйте всі функції та ексклюзивні ефекти.',
    },
    slogans: {
      'en': 'Shine Brighter',
      'ru': 'Свети ярче',
      'ua': 'Світи яскравіше',
    },
    gradientColors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
  ),
  AppBanner(
    id: 'music_sync',
    titles: {
      'en': 'Music Sync',
      'ru': 'Светомузыка',
      'ua': 'Світломузика',
    },
    descriptions: {
      'en': 'Sync your lights to the rhythm of your favorite tracks.',
      'ru': 'Синхронизируйте свет с ритмом ваших любимых треков.',
      'ua': 'Синхронізуйте світло з ритмом ваших улюблених треків.',
    },
    slogans: {
      'en': 'Feel the Beat',
      'ru': 'Почувствуй ритм',
      'ua': 'Відчуй ритм',
    },
    gradientColors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
  ),
  AppBanner(
    id: 'cyber_mode',
    titles: {
      'en': 'Cyberpunk Mode',
      'ru': 'Режим Киберпанк',
      'ua': 'Режим Кіберпанк',
    },
    descriptions: {
      'en': 'Immerse into the neon future with deep cyber themes.',
      'ru': 'Погрузитесь в неоновое будущее с нашими кибер-темами.',
      'ua': 'Пориньте у неонове майбутнє з кібер-темами.',
    },
    slogans: {
      'en': 'Neon Future',
      'ru': 'Неоновое будущее',
      'ua': 'Неонове майбутнє',
    },
    gradientColors: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
  ),
];
