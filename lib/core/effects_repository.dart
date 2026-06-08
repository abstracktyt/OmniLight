import 'package:flutter/material.dart';

enum EffectCategory {
  colorFlow,
  strobe,
  pulse,
  nature,
  special
}

class AppEffect {
  final String id;
  final Map<String, String> names;
  final EffectCategory category;
  final List<Color> previewColors;

  const AppEffect({
    required this.id,
    required this.names,
    required this.category,
    required this.previewColors,
  });
}

class EffectsRepository {
  static final List<AppEffect> _complexEffects = [
    const AppEffect(
      id: 'rainbow_flow',
      names: {'en': 'Rainbow Flow', 'ru': 'Перелив радуги', 'ua': 'Перелив веселки'},
      category: EffectCategory.colorFlow,
      previewColors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
    ),
    const AppEffect(
      id: 'rainbow_chase',
      names: {'en': 'Rainbow Chase', 'ru': 'Радужная погоня', 'ua': 'Райдужна погоня'},
      category: EffectCategory.colorFlow,
      previewColors: [Colors.purple, Colors.red, Colors.yellow],
    ),
    const AppEffect(
      id: 'rainbow_strobe',
      names: {'en': 'Rainbow Strobe', 'ru': 'Радужный стробоскоп', 'ua': 'Райдужний стробоскоп'},
      category: EffectCategory.strobe,
      previewColors: [Colors.blue, Colors.white, Colors.red],
    ),
    const AppEffect(
      id: 'pastel_flow',
      names: {'en': 'Pastel Flow', 'ru': 'Пастельный перелив', 'ua': 'Пастельний перелив'},
      category: EffectCategory.colorFlow,
      previewColors: [Color(0xFFFFB3BA), Color(0xFFFFDFBA), Color(0xFFFFFFBA), Color(0xFFBAFFC9), Color(0xFFBAE1FF)],
    ),
    const AppEffect(
      id: 'toxic_flow',
      names: {'en': 'Acid Flow', 'ru': 'Кислотный перелив', 'ua': 'Кислотний перелив'},
      category: EffectCategory.special,
      previewColors: [Color(0xFFCCFF00), Color(0xFF00FF66)],
    ),
    const AppEffect(
      id: 'rgb_fade',
      names: {'en': 'RGB Fade', 'ru': 'Затухание RGB', 'ua': 'Загасання RGB'},
      category: EffectCategory.colorFlow,
      previewColors: [Colors.red, Colors.green, Colors.blue],
    ),
    const AppEffect(
      id: 'fire_glow',
      names: {'en': 'Fire Glow', 'ru': 'Свечение огня', 'ua': 'Світіння вогню'},
      category: EffectCategory.nature,
      previewColors: [Colors.red, Colors.orange, Colors.yellow],
    ),
    const AppEffect(
      id: 'ice_cold',
      names: {'en': 'Ice Cold', 'ru': 'Ледяной холод', 'ua': 'Крижаний холод'},
      category: EffectCategory.nature,
      previewColors: [Colors.cyan, Colors.blue, Colors.white],
    ),
    const AppEffect(
      id: 'forest_breath',
      names: {'en': 'Forest Breath', 'ru': 'Дыхание леса', 'ua': 'Дихання лісу'},
      category: EffectCategory.nature,
      previewColors: [Colors.green, Colors.lightGreen, Colors.teal],
    ),
    const AppEffect(
      id: 'neon_night',
      names: {'en': 'Neon Night', 'ru': 'Неоновая ночь', 'ua': 'Неонова ніч'},
      category: EffectCategory.special,
      previewColors: [Colors.pinkAccent, Colors.purpleAccent, Colors.blueAccent],
    ),
    const AppEffect(
      id: 'aurora',
      names: {'en': 'Aurora Borealis', 'ru': 'Северное сияние', 'ua': 'Північне сяйво'},
      category: EffectCategory.nature,
      previewColors: [Color(0xFF00FF9D), Color(0xFF00B8FF), Color(0xFF7A00FF)],
    ),
    const AppEffect(
      id: 'thunderstorm',
      names: {'en': 'Thunderstorm', 'ru': 'Гроза', 'ua': 'Гроза'},
      category: EffectCategory.nature,
      previewColors: [Color(0xFF1a0033), Color(0xFFFFFFFF)],
    ),
    const AppEffect(
      id: 'police',
      names: {'en': 'Police Flasher', 'ru': 'Полицейская мигалка', 'ua': 'Поліцейська мигалка'},
      category: EffectCategory.special,
      previewColors: [Colors.red, Colors.blue],
    ),
    const AppEffect(
      id: 'police_double',
      names: {'en': 'Police Double Strobe', 'ru': 'Полиция (Двойной)', 'ua': 'Поліція (Подвійний)'},
      category: EffectCategory.strobe,
      previewColors: [Colors.red, Colors.black, Colors.blue, Colors.black],
    ),
    const AppEffect(
      id: 'heartbeat',
      names: {'en': 'Heartbeat', 'ru': 'Сердцебиение', 'ua': 'Серцебиття'},
      category: EffectCategory.pulse,
      previewColors: [Color(0xFFFF0000), Color(0xFF440000)],
    ),
    const AppEffect(
      id: 'gold_rush',
      names: {'en': 'Gold Rush', 'ru': 'Золотая лихорадка', 'ua': 'Золота лихоманка'},
      category: EffectCategory.special,
      previewColors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFF8B6508)],
    ),
    const AppEffect(
      id: 'neon_flash',
      names: {'en': 'Neon Flash', 'ru': 'Неоновые вспышки', 'ua': 'Неонові спалахи'},
      category: EffectCategory.strobe,
      previewColors: [Colors.pinkAccent, Colors.cyanAccent, Colors.yellowAccent],
    ),
  ];

  static final Map<String, Map<String, String>> _baseColors = {
    'FF0000': {'en': 'Red', 'ru': 'Красный', 'ua': 'Червоний'},
    '00FF00': {'en': 'Green', 'ru': 'Зеленый', 'ua': 'Зелений'},
    '0000FF': {'en': 'Blue', 'ru': 'Синий', 'ua': 'Синій'},
    'FFFF00': {'en': 'Yellow', 'ru': 'Желтый', 'ua': 'Жовтий'},
    '00FFFF': {'en': 'Cyan', 'ru': 'Бирюзовый', 'ua': 'Бірюзовий'},
    'FF00FF': {'en': 'Magenta', 'ru': 'Пурпурный', 'ua': 'Пурпуровий'},
    'FFFFFF': {'en': 'White', 'ru': 'Белый', 'ua': 'Білий'},
    'FF6600': {'en': 'Orange', 'ru': 'Оранжевый', 'ua': 'Помаранчевий'},
    'FF0066': {'en': 'Pink', 'ru': 'Розовый', 'ua': 'Рожевий'},
    '6600FF': {'en': 'Purple', 'ru': 'Фиолетовый', 'ua': 'Фіолетовий'},
    '008080': {'en': 'Teal', 'ru': 'Морской волны', 'ua': 'Морської хвилі'},
    '80FF00': {'en': 'Lime', 'ru': 'Лаймовый', 'ua': 'Лаймовий'},
    'FFD700': {'en': 'Gold', 'ru': 'Золотой', 'ua': 'Золотий'},
  };

  static List<AppEffect> getAllEffects() {
    List<AppEffect> all = [];
    all.addAll(_complexEffects);

    // Generate Pulses, Strobes, and Double Strobes
    _baseColors.forEach((hex, names) {
      final color = Color(int.parse("FF$hex", radix: 16));
      
      all.add(AppEffect(
        id: 'pulse_$hex',
        names: {
          'en': '${names['en']} Pulse',
          'ru': '${names['ru']} (Пульсация)',
          'ua': '${names['ua']} (Пульсація)',
        },
        category: EffectCategory.pulse,
        previewColors: [color, color.withAlpha((255 * 0.2).toInt())],
      ));

      all.add(AppEffect(
        id: 'strobe_$hex',
        names: {
          'en': '${names['en']} Strobe',
          'ru': '${names['ru']} (Строб)',
          'ua': '${names['ua']} (Строб)',
        },
        category: EffectCategory.strobe,
        previewColors: [color, Colors.black],
      ));

      all.add(AppEffect(
        id: 'dblstrobe_$hex',
        names: {
          'en': '${names['en']} Double Strobe',
          'ru': '${names['ru']} (Двойной строб)',
          'ua': '${names['ua']} (Подвійний строб)',
        },
        category: EffectCategory.strobe,
        previewColors: [color, Colors.black, color],
      ));
    });

    // Generate Chasers and Fades (Combinations of 2 colors)
    final keys = _baseColors.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      for (int j = i + 1; j < keys.length; j++) {
        final hex1 = keys[i];
        final hex2 = keys[j];
        final name1 = _baseColors[hex1]!;
        final name2 = _baseColors[hex2]!;
        final color1 = Color(int.parse("FF$hex1", radix: 16));
        final color2 = Color(int.parse("FF$hex2", radix: 16));

        all.add(AppEffect(
          id: 'chase_${hex1}_$hex2',
          names: {
            'en': '${name1['en']}-${name2['en']} Chase',
            'ru': '${name1['ru']}-${name2['ru']} (Мигалка)',
            'ua': '${name1['ua']}-${name2['ua']} (Мигалка)',
          },
          category: EffectCategory.special,
          previewColors: [color1, color2],
        ));

        all.add(AppEffect(
          id: 'fade_${hex1}_$hex2',
          names: {
            'en': '${name1['en']}-${name2['en']} Fade',
            'ru': '${name1['ru']}-${name2['ru']} (Перелив)',
            'ua': '${name1['ua']}-${name2['ua']} (Перелив)',
          },
          category: EffectCategory.colorFlow,
          previewColors: [color1, color2],
        ));
      }
    }

    return all;
  }
}
