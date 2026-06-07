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
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, ChangeNotifier;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../drivers/led_driver.dart';

// Проверка: работаем ли мы на мобильной платформе (iOS/Android)
// BLE flutter_blue_plus не поддерживает Web, Windows, Linux
bool get _isBleSupported =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

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

  // ── История подключений ──
  List<Map<String, String>> _connectionHistory = [];
  List<Map<String, String>> get connectionHistory => _connectionHistory;

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('omnilight_history_ids') ?? [];
      final names = prefs.getStringList('omnilight_history_names') ?? [];
      _connectionHistory = [];
      for (int i = 0; i < ids.length; i++) {
        if (i < names.length) {
          _connectionHistory.add({'id': ids[i], 'name': names[i]});
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка загрузки истории: $e');
    }
  }

  Future<void> _addToHistory(String id, String name) async {
    // Проверяем, есть ли уже в истории, и удаляем дубликат
    _connectionHistory.removeWhere((item) => item['id'] == id);
    _connectionHistory.insert(0, {'id': id, 'name': name});
    
    // Ограничиваем историю 10 устройствами
    if (_connectionHistory.length > 10) {
      _connectionHistory = _connectionHistory.sublist(0, 10);
    }
    
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _connectionHistory.map((item) => item['id']!).toList();
      final names = _connectionHistory.map((item) => item['name']!).toList();
      await prefs.setStringList('omnilight_history_ids', ids);
      await prefs.setStringList('omnilight_history_names', names);
      notifyListeners();
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка сохранения истории: $e');
    }
  }

  Future<void> clearHistory() async {
    _connectionHistory.clear();
    await _saveHistory();
  }

  Future<void> removeFromHistory(String id) async {
    _connectionHistory.removeWhere((item) => item['id'] == id);
    await _saveHistory();
  }

  // ── Внутренние подписки ──
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  // ─────────────────────────────────────────────
  // Инициализация: подписка на изменения состояния BLE-адаптера iOS
  // ─────────────────────────────────────────────
  Future<void> init() async {
    await _loadHistory();
    // На Web/Desktop BLE недоступен — пропускаем инициализацию
    if (!_isBleSupported) {
      debugPrint('[OmniLight/DeviceManager] BLE недоступен на этой платформе (только iOS/Android)');
      return;
    }
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
    if (!_isBleSupported) {
      debugPrint('[OmniLight/DeviceManager] startScan: BLE недоступен на этой платформе');
      _setError('Близкая связь (BLE) доступна только на мобильных устройствах (iOS/Android)');
      return;
    }
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

    // Сначала опрашиваем устройства, которые уже подключены к системе (iOS Auto-Connect или другая программа)
    try {
      final systemDevices = await FlutterBluePlus.systemDevices(
        [
          Guid('0000fff0-0000-1000-8000-00805f9b34fb'), // BLEDOM
          Guid('0000ffd0-0000-1000-8000-00805f9b34fb'), // SP110E
        ],
      );
      for (final device in systemDevices) {
        final deviceName = device.platformName.isNotEmpty
            ? device.platformName
            : 'ELK-BLEDOM';
        
        final matchedDriver = _matchDriver(deviceName);
        
        final exists = _discoveredDevices.any((d) => d.device.remoteId == device.remoteId);
        if (!exists) {
          _discoveredDevices.add(DiscoveredDevice(
            device: device,
            name: deviceName,
            rssi: -55,
            matchedDriver: matchedDriver,
          ));
        }
      }
      if (_discoveredDevices.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка при получении подключенных к системе устройств: $e');
    }

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
      await _addToHistory(discovered.device.remoteId.toString(), discovered.name);
      debugPrint(
        '[OmniLight/DeviceManager] Подключено: ${discovered.name} '
        'через ${driver.driverName}',
      );
    } catch (e) {
      debugPrint('[OmniLight/DeviceManager] Ошибка подключения к ${discovered.name}: $e');
      _setError('Не удалось подключиться к ${discovered.name}: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Подключиться к сохранённому устройству из истории
  // ─────────────────────────────────────────────
  Future<void> connectToSavedDevice(String id, String name) async {
    if (!_isBleSupported) {
      debugPrint('[OmniLight/DeviceManager] connectToSavedDevice: BLE недоступен');
      return;
    }
    await stopScan();
    final device = BluetoothDevice.fromId(id);
    final matchedDriver = _matchDriver(name);
    final discovered = DiscoveredDevice(
      device: device,
      name: name,
      rssi: -50,
      matchedDriver: matchedDriver,
    );
    await connectToDevice(discovered);
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
