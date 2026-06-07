// ============================================================
// OmniLight by Abstrackt
// Файл: device_manager.dart
// Назначение: Менеджер BLE-устройств (DeviceManager).
//
//             Отвечает за:
//               1. Проверку состояния iOS BLE-разрешений и адаптера
//               2. Сканирование окружающих BLE-устройств
//               3. Сопоставление имени/MAC с конкретным LED-драйвером
//               4. Инициализацию и управление жизненным циклом драйвера
//               5. Трансляцию агрегированного состояния в UI через ChangeNotifier
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../drivers/led_driver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Перечисление: состояния менеджера (агрегирует BLE + driver state)
// ─────────────────────────────────────────────────────────────────────────────
enum DeviceManagerState {
  bleUnavailable,  // BLE не поддерживается устройством
  bleOff,          // BLE выключен пользователем
  permissionDenied,// iOS отклонил запрос разрешения Bluetooth
  idle,            // Готов к работе, ничего не делает
  scanning,        // Идёт сканирование BLE
  connecting,      // Подключение к выбранному устройству
  connected,       // Активное соединение с LED-контроллером
  error,           // Произошла ошибка
}

// ─────────────────────────────────────────────────────────────────────────────
// Класс: DiscoveredDevice
// Назначение: Обёртка над BluetoothDevice, хранит имя, RSSI и
//             предполагаемый тип драйвера (если удалось определить).
// ─────────────────────────────────────────────────────────────────────────────
class DiscoveredDevice {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  final BaseLedDriver? matchedDriver; // null — протокол неизвестен

  const DiscoveredDevice({
    required this.device,
    required this.name,
    required this.rssi,
    this.matchedDriver,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Класс: DeviceManager
// Назначение: Центральный провайдер для управления BLE-сессией.
//             Реализует ChangeNotifier для реактивного UI через Provider.
// ─────────────────────────────────────────────────────────────────────────────
class DeviceManager extends ChangeNotifier {
  // ── Реестр доступных драйверов (добавляйте новые сюда) ──
  // При добавлении нового протокола — просто добавьте экземпляр драйвера в список.
  final List<BaseLedDriver> _availableDrivers = [
    Sp110eDriver(),
    ElkBledomDriver(),
  ];

  // ── Текущее состояние менеджера ──
  DeviceManagerState _state = DeviceManagerState.idle;
  DeviceManagerState get state => _state;

  // ── Список обнаруженных при сканировании устройств ──
  final List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  // ── Активный драйвер (установлен после успешного соединения) ──
  BaseLedDriver? _activeDriver;
  BaseLedDriver? get activeDriver => _activeDriver;

  // ── Имя подключённого устройства (для UI) ──
  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  // ── Сообщение последней ошибки ──
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Текущий уровень яркости (0–255) ──
  int _brightness = 255;
  int get brightness => _brightness;

  // ── Текущий цвет RGB ──
  int _red = 255, _green = 255, _blue = 255;
  int get red => _red;
  int get green => _green;
  int get blue => _blue;

  // ── Внутренние подписки ──
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  // ─────────────────────────────────────────────
  // Инициализация: подписка на изменения состояния BLE-адаптера iOS
  // ─────────────────────────────────────────────
  Future<void> init() async {
    // Слушаем изменения состояния адаптера (включён/выключен/недоступен)
    _adapterSubscription =
        FlutterBluePlus.adapterState.listen(_onAdapterStateChanged);

    // Читаем текущее состояние сразу при запуске
    final currentState = await FlutterBluePlus.adapterState.first;
    _onAdapterStateChanged(currentState);
  }

  // ─────────────────────────────────────────────
  // Обработчик изменений состояния BLE-адаптера
  // ─────────────────────────────────────────────
  void _onAdapterStateChanged(BluetoothAdapterState adapterState) {
    debugPrint('[OmniLight/DeviceManager] Состояние адаптера: $adapterState');
    switch (adapterState) {
      case BluetoothAdapterState.on:
        // BLE включён и готов к работе
        if (_state == DeviceManagerState.bleOff ||
            _state == DeviceManagerState.bleUnavailable) {
          _setState(DeviceManagerState.idle);
        }
        break;

      case BluetoothAdapterState.off:
        // Пользователь выключил Bluetooth
        _setState(DeviceManagerState.bleOff);
        break;

      case BluetoothAdapterState.unavailable:
        // Устройство не поддерживает BLE
        _setState(DeviceManagerState.bleUnavailable);
        break;

      case BluetoothAdapterState.unauthorized:
        // iOS отклонил разрешение на доступ к Bluetooth
        _setState(DeviceManagerState.permissionDenied);
        break;

      default:
        break;
    }
  }

  // ─────────────────────────────────────────────
  // Запустить сканирование BLE-устройств
  // Длительность: 10 секунд (стандартный iOS таймаут)
  // ─────────────────────────────────────────────
  Future<void> startScan() async {
    if (_state == DeviceManagerState.scanning) {
      debugPrint('[OmniLight/DeviceManager] Сканирование уже запущено');
      return;
    }
    if (_state == DeviceManagerState.connected) {
      debugPrint('[OmniLight/DeviceManager] Активное соединение, сканирование запрещено');
      return;
    }

    // Очищаем предыдущие результаты
    _discoveredDevices.clear();
    _setState(DeviceManagerState.scanning);

    try {
      // Подписываемся на поток результатов сканирования
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onError: (e) {
          debugPrint('[OmniLight/DeviceManager] Ошибка сканирования: $e');
          _setError('Ошибка сканирования: $e');
        },
      );

      // Запускаем сканирование с таймаутом 10 секунд
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false, // Только для Android
      );

      // Ожидаем завершения таймаута
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка запуска сканирования: $e');
      _setError('Не удалось запустить сканирование: $e');
    } finally {
      // Гарантируем остановку и переход в idle
      await stopScan();
    }
  }

  // ─────────────────────────────────────────────
  // Остановить сканирование
  // ─────────────────────────────────────────────
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    if (_state == DeviceManagerState.scanning) {
      _setState(DeviceManagerState.idle);
    }
  }

  // ─────────────────────────────────────────────
  // Обработчик результатов сканирования
  // ─────────────────────────────────────────────
  void _onScanResults(List<ScanResult> results) {
    bool changed = false;

    for (final result in results) {
      final deviceName = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : (result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Unknown');

      // Пропускаем безымянные устройства (снижаем шум в списке)
      if (deviceName == 'Unknown' || deviceName.isEmpty) continue;

      // Проверяем, не добавлено ли уже это устройство
      final alreadyFound = _discoveredDevices.any(
        (d) => d.device.remoteId == result.device.remoteId,
      );
      if (alreadyFound) continue;

      // Определяем, какой драйвер подходит для этого устройства
      final matchedDriver = _matchDriver(deviceName);

      debugPrint(
        '[OmniLight/DeviceManager] Найдено: $deviceName '
        '(драйвер: ${matchedDriver?.driverName ?? "нет"})',
      );

      _discoveredDevices.add(DiscoveredDevice(
        device: result.device,
        name: deviceName,
        rssi: result.rssi,
        matchedDriver: matchedDriver,
      ));

      changed = true;
    }

    if (changed) notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Сопоставление имени устройства с драйвером
  // Возвращает первый подходящий драйвер или null.
  // ─────────────────────────────────────────────
  BaseLedDriver? _matchDriver(String deviceName) {
    final upperName = deviceName.toUpperCase();
    for (final driver in _availableDrivers) {
      for (final pattern in driver.deviceNamePatterns) {
        if (upperName.contains(pattern.toUpperCase())) {
          return driver;
        }
      }
    }
    // Неизвестный протокол — возвращаем null (устройство всё равно показывается)
    return null;
  }

  // ─────────────────────────────────────────────
  // Подключиться к выбранному устройству
  // ─────────────────────────────────────────────
  Future<void> connectToDevice(DiscoveredDevice discovered) async {
    await stopScan();

    // Определяем драйвер: используем предопределённый или ELK по умолчанию
    final driver = discovered.matchedDriver ?? ElkBledomDriver();
    _setState(DeviceManagerState.connecting);

    try {
      await driver.connect(discovered.device);
      _activeDriver = driver;
      _connectedDeviceName = discovered.name;
      _setState(DeviceManagerState.connected);
      debugPrint(
        '[OmniLight/DeviceManager] Подключено: ${discovered.name} '
        'через ${driver.driverName}',
      );
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка подключения к ${discovered.name}: $e');
      _setError('Не удалось подключиться к ${discovered.name}');
    }
  }

  // ─────────────────────────────────────────────
  // Отключиться от текущего устройства
  // ─────────────────────────────────────────────
  Future<void> disconnectCurrent() async {
    await _activeDriver?.disconnect();
    _activeDriver = null;
    _connectedDeviceName = null;
    _setState(DeviceManagerState.idle);
  }

  // ─────────────────────────────────────────────
  // Команда: установить цвет RGB (с сохранением состояния в UI)
  // ─────────────────────────────────────────────
  Future<void> setRgb(int r, int g, int b) async {
    if (_activeDriver == null) return;
    _red = r;
    _green = g;
    _blue = b;
    notifyListeners();
    await _activeDriver!.setRgb(r, g, b);
  }

  // ─────────────────────────────────────────────
  // Команда: установить яркость
  // ─────────────────────────────────────────────
  Future<void> setBrightness(int level) async {
    if (_activeDriver == null) return;
    _brightness = level.clamp(0, 255);
    notifyListeners();
    await _activeDriver!.setBrightness(_brightness);
  }

  // ─────────────────────────────────────────────
  // Команда: включить
  // ─────────────────────────────────────────────
  Future<void> turnOn() async => await _activeDriver?.turnOn();

  // ─────────────────────────────────────────────
  // Команда: выключить
  // ─────────────────────────────────────────────
  Future<void> turnOff() async => await _activeDriver?.turnOff();

  // ─────────────────────────────────────────────
  // Вспомогательные методы изменения состояния
  // ─────────────────────────────────────────────
  void _setState(DeviceManagerState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _state = DeviceManagerState.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Освобождение ресурсов
  // ─────────────────────────────────────────────
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    _activeDriver?.disconnect();
    super.dispose();
  }
}
