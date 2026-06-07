// ============================================================
// OmniLight by Abstrackt
// Файл: led_driver.dart
// Назначение: Абстрактный интерфейс BaseLedDriver и две конкретные
//             реализации драйверов LED-лент:
//               1. Sp110eDriver  — контроллер SP110E (пакеты R,G,B,0x1E)
//               2. ElkBledomDriver — контроллер ELK-BLEDOM (пакет 0x7E…0xEF)
//
//             Паттерн Адаптер/Драйвер позволяет добавлять новые протоколы
//             без изменения вышестоящего кода — достаточно создать новый
//             класс-наследник BaseLedDriver.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный класс: BleServiceConfig
// Назначение: Хранит UUID сервиса и характеристики, через которую
//             отправляются управляющие команды на конкретное устройство.
//             Каждый драйвер объявляет собственный конфиг.
// ─────────────────────────────────────────────────────────────────────────────
class BleServiceConfig {
  final String serviceUuid;
  final String characteristicUuid;

  const BleServiceConfig({
    required this.serviceUuid,
    required this.characteristicUuid,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Перечисление: возможные состояния драйвера
// ─────────────────────────────────────────────────────────────────────────────
enum DriverState {
  disconnected, // Нет активного подключения
  connecting,   // Попытка подключения
  connected,    // Подключён и готов к работе
  error,        // Ошибка подключения или передачи данных
}

// ─────────────────────────────────────────────────────────────────────────────
// Абстрактный класс: BaseLedDriver
// Назначение: Определяет обязательный API для всех конкретных драйверов.
//             Любая новая реализация (МагниТуман, TRIONES и др.) должна
//             наследоваться от этого класса и реализовать все методы.
// ─────────────────────────────────────────────────────────────────────────────
abstract class BaseLedDriver {
  // ── Конфигурация BLE (UUID сервиса и характеристики) ──
  BleServiceConfig get serviceConfig;

  // ── Человекочитаемое название протокола ──
  String get driverName;

  // ── Паттерны имён устройств, соответствующих этому драйверу ──
  List<String> get deviceNamePatterns;

  // ── Текущее подключённое устройство ──
  BluetoothDevice? get device;

  // ── Текущее состояние драйвера ──
  DriverState get state;

  // ── Стрим состояния для реактивного UI ──
  Stream<DriverState> get stateStream;

  // ─────────────────────────────────────────────
  // Основные методы управления (обязательны к реализации)
  // ─────────────────────────────────────────────

  /// Подключиться к указанному BLE-устройству.
  /// Выполняет GATT-соединение, обнаружение сервисов и
  /// сохраняет ссылку на характеристику для записи команд.
  Future<void> connect(BluetoothDevice targetDevice);

  /// Отключиться от текущего устройства.
  Future<void> disconnect();

  /// Установить цвет RGB (каждый компонент 0–255).
  Future<void> setRgb(int r, int g, int b);

  /// Установить яркость (level: 0–255).
  Future<void> setBrightness(int level);

  /// Включить LED-ленту.
  Future<void> turnOn();

  /// Выключить LED-ленту.
  Future<void> turnOff();
}

// ─────────────────────────────────────────────────────────────────────────────
// Базовая реализация: _BaseDriverImpl
// Назначение: Содержит общую логику подключения/отключения и отправки пакетов,
//             которую переиспользуют конкретные драйверы через наследование.
//             Снижает дублирование кода между Sp110eDriver и ElkBledomDriver.
// ─────────────────────────────────────────────────────────────────────────────
abstract class _BaseDriverImpl extends BaseLedDriver {
  // ── Внутреннее состояние ──
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  DriverState _state = DriverState.disconnected;

  // ── StreamController для трансляции состояния в UI ──
  final _stateController = StreamController<DriverState>.broadcast();

  @override
  BluetoothDevice? get device => _device;

  @override
  DriverState get state => _state;

  @override
  Stream<DriverState> get stateStream => _stateController.stream;

  // ─────────────────────────────────────────────
  // Вспомогательный метод: изменить и транслировать состояние
  // ─────────────────────────────────────────────
  void _setState(DriverState newState) {
    _state = newState;
    _stateController.add(newState);
    debugPrint('[OmniLight/${driverName}] Состояние: $newState');
  }

  // ─────────────────────────────────────────────
  // Подключение к устройству
  // ─────────────────────────────────────────────
  @override
  Future<void> connect(BluetoothDevice targetDevice) async {
    _setState(DriverState.connecting);
    try {
      _device = targetDevice;

      // Устанавливаем GATT-соединение с таймаутом 10 секунд
      await targetDevice.connect(timeout: const Duration(seconds: 10));

      // Обнаруживаем все GATT-сервисы устройства
      final services = await targetDevice.discoverServices();

      // Ищем нужный сервис по UUID из конфигурации драйвера
      BluetoothService? targetService;
      for (final service in services) {
        if (_compareUuids(service.uuid, serviceConfig.serviceUuid)) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        final serviceUuids = services.map((s) => s.uuid.toString()).join(', ');
        throw Exception(
          'Сервис ${serviceConfig.serviceUuid} не найден. Доступны: [$serviceUuids]',
        );
      }

      // Ищем нужную характеристику по UUID
      BluetoothCharacteristic? targetChar;
      for (final char in targetService.characteristics) {
        if (_compareUuids(char.uuid, serviceConfig.characteristicUuid)) {
          targetChar = char;
          break;
        }
      }

      if (targetChar == null) {
        final charUuids = targetService.characteristics.map((c) => c.uuid.toString()).join(', ');
        throw Exception(
          'Характеристика ${serviceConfig.characteristicUuid} не найдена. Доступны: [$charUuids]',
        );
      }

      _writeChar = targetChar;
      _setState(DriverState.connected);
      debugPrint('[OmniLight/${driverName}] Подключено: ${targetDevice.platformName}');
    } catch (e) {
      _setState(DriverState.error);
      debugPrint('[OmniLight/${driverName}] Ошибка подключения: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Отключение от устройства
  // ─────────────────────────────────────────────
  @override
  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (e) {
      debugPrint('[OmniLight/${driverName}] Ошибка при отключении: $e');
    } finally {
      _device = null;
      _writeChar = null;
      _setState(DriverState.disconnected);
    }
  }

  // ─────────────────────────────────────────────
  // Отправка байтового пакета на характеристику
  // ─────────────────────────────────────────────
  Future<void> sendPacket(List<int> bytes) async {
    if (_writeChar == null) {
      debugPrint('[OmniLight/${driverName}] Характеристика не инициализирована, пакет отброшен');
      return;
    }
    try {
      // Используем writeWithoutResponse для максимальной пропускной способности
      // (подходит для потоков цвета в реальном времени)
      await _writeChar!.write(bytes, withoutResponse: true);
      debugPrint('[OmniLight/${driverName}] Отправлен пакет: $bytes');
    } catch (e) {
      debugPrint('[OmniLight/${driverName}] Ошибка отправки пакета: $e');
      _setState(DriverState.error);
    }
  }

  // ─────────────────────────────────────────────
  // Освобождение ресурсов StreamController
  // ─────────────────────────────────────────────
  void dispose() {
    _stateController.close();
  }

  bool _compareUuids(Guid guid, String configUuidStr) {
    if (guid == Guid(configUuidStr)) return true;
    final clean1 = guid.toString().replaceAll('-', '').toLowerCase();
    final clean2 = configUuidStr.replaceAll('-', '').toLowerCase();
    if (clean1 == clean2) return true;
    if (clean1.length == 4 && clean2.length == 32) {
      return clean2.startsWith('0000$clean1');
    }
    if (clean2.length == 4 && clean1.length == 32) {
      return clean1.startsWith('0000$clean2');
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Конкретный драйвер: Sp110eDriver
// Протокол: SP110E (широко распространённый бюджетный BLE-контроллер)
//
// Формат пакета цвета: [R, G, B, 0x1E]
// Формат включения:    [0x00, 0x00, 0x01, 0x1E] (или специфичная команда)
// Формат выключения:   [0x00, 0x00, 0x00, 0x1E]
// Яркость:             [0x00, level, 0x00, 0x1A]
//
// UUID сервиса и характеристики стандартные для SP110E (FFD0 / FFD9)
// ─────────────────────────────────────────────────────────────────────────────
class Sp110eDriver extends _BaseDriverImpl {
  @override
  String get driverName => 'SP110E';

  // Паттерны имён BLE-устройств, которые относятся к этому протоколу
  @override
  List<String> get deviceNamePatterns => ['SP110E', 'SP-110E', 'SP110'];

  // Стандартные UUID для SP110E
  @override
  BleServiceConfig get serviceConfig => const BleServiceConfig(
    serviceUuid: 'ffd0',
    characteristicUuid: 'ffd9',
  );

  // ─────────────────────────────────────────────
  // Команда: установить цвет RGB
  // Структура: [R, G, B, 0x1E]
  // ─────────────────────────────────────────────
  @override
  Future<void> setRgb(int r, int g, int b) async {
    // Зажимаем значения в диапазоне 0–255 для защиты от входных ошибок
    final clampedR = r.clamp(0, 255);
    final clampedG = g.clamp(0, 255);
    final clampedB = b.clamp(0, 255);
    await sendPacket([clampedR, clampedG, clampedB, 0x1E]);
  }

  // ─────────────────────────────────────────────
  // Команда: установить яркость
  // Структура: [0x00, level, 0x00, 0x1A]
  // ─────────────────────────────────────────────
  @override
  Future<void> setBrightness(int level) async {
    final clamped = level.clamp(0, 255);
    await sendPacket([0x00, clamped, 0x00, 0x1A]);
  }

  // ─────────────────────────────────────────────
  // Команда: включить (Turn ON)
  // ─────────────────────────────────────────────
  @override
  Future<void> turnOn() async {
    // Для SP110E включение — отправка бита питания 0x01 с командой 0x1E
    await sendPacket([0x00, 0x00, 0x01, 0x1E]);
  }

  // ─────────────────────────────────────────────
  // Команда: выключить (Turn OFF)
  // ─────────────────────────────────────────────
  @override
  Future<void> turnOff() async {
    // Выключение — отправка нулевых RGB значений
    await sendPacket([0x00, 0x00, 0x00, 0x1E]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Конкретный драйвер: ElkBledomDriver
// Протокол: ELK-BLEDOM (популярный китайский BLE LED-контроллер)
//
// Формат пакета цвета:
//   [0x7E, 0x07, 0x05, 0x03, R, G, B, 0x10, 0xEF]
//
// Формат включения:
//   [0x7E, 0x04, 0x04, 0xF0, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xEF]
//
// Формат выключения:
//   [0x7E, 0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xEF]
//
// UUID сервиса: 0000fff0-... (стандартный для BLEDOM)
// UUID характеристики: 0000fff3-...
// ─────────────────────────────────────────────────────────────────────────────
class ElkBledomDriver extends _BaseDriverImpl {
  @override
  String get driverName => 'ELK-BLEDOM';

  // Паттерны имён BLE-устройств ELK-BLEDOM серии
  @override
  List<String> get deviceNamePatterns => [
    'ELK-BLEDOM',
    'BLEDOM',
    'ELK_BLEDOM',
    'LEDBLE',
    'iLinker', // Некоторые устройства используют этот бренд
    'QHM-BLS', // Другой вариант прошивки BLEDOM
  ];

  // UUID сервиса и характеристики ELK-BLEDOM (стандарт FFF0/FFF3)
  @override
  BleServiceConfig get serviceConfig => const BleServiceConfig(
    serviceUuid: '0000fff0-0000-1000-8000-00805f9b34fb',
    characteristicUuid: '0000fff3-0000-1000-8000-00805f9b34fb',
  );

  // ─────────────────────────────────────────────
  // Команда: установить цвет RGB
  // Структура: [0x7E, 0x07, 0x05, 0x03, R, G, B, 0x10, 0xEF]
  // Байт 0x10 — режим статического цвета (не анимация)
  // ─────────────────────────────────────────────
  @override
  Future<void> setRgb(int r, int g, int b) async {
    final clampedR = r.clamp(0, 255);
    final clampedG = g.clamp(0, 255);
    final clampedB = b.clamp(0, 255);
    await sendPacket([
      0x7E, // Стартовый байт протокола BLEDOM
      0x07, // Длина данных
      0x05, // Команда: установить цвет
      0x03, // Тип цвета: RGB
      clampedR,
      clampedG,
      clampedB,
      0x10, // Режим: статический цвет
      0xEF, // Конечный байт протокола
    ]);
  }

  // ─────────────────────────────────────────────
  // Команда: установить яркость
  // Структура: [0x7E, 0x04, 0x01, level, 0xFF, 0xFF, 0xFF, 0x00, 0xEF]
  // level: 0x00 (0%) … 0x64 (100%), но мы принимаем 0–255 и нормализуем
  // ─────────────────────────────────────────────
  @override
  Future<void> setBrightness(int level) async {
    // Нормализуем из диапазона 0–255 в 0–100 (формат BLEDOM)
    final normalized = (level.clamp(0, 255) * 100 ~/ 255);
    await sendPacket([
      0x7E,
      0x04,
      0x01,        // Команда яркости
      normalized,  // Значение яркости 0–100
      0xFF,
      0xFF,
      0xFF,
      0x00,
      0xEF,
    ]);
  }

  // ─────────────────────────────────────────────
  // Команда: включить
  // ─────────────────────────────────────────────
  @override
  Future<void> turnOn() async {
    await sendPacket([
      0x7E, 0x04, 0x04, 0xF0, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xEF,
    ]);
  }

  // ─────────────────────────────────────────────
  // Команда: выключить
  // ─────────────────────────────────────────────
  @override
  Future<void> turnOff() async {
    await sendPacket([
      0x7E, 0x04, 0x04, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xEF,
    ]);
  }
}
