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
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../drivers/led_driver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Класс: AppEffect
// Назначение: Описание эффекта с поддержкой мультиязычности и кодов
//             эффектов для разных контроллеров.
// ─────────────────────────────────────────────────────────────────────────────
class AppEffect {
  final String id;
  final Map<String, String> names;
  final Map<String, int> driverEffectIds;
  final List<Color> previewColors;

  const AppEffect({
    required this.id,
    required this.names,
    required this.driverEffectIds,
    required this.previewColors,
  });
}

const List<AppEffect> appEffects = [
  AppEffect(
    id: 'rainbow_flow',
    names: {'en': 'Rainbow Flow', 'ru': 'Радужный перелив', 'ua': 'Радужний перелив'},
    driverEffectIds: {'ELK-BLEDOM': 138, 'SP110E': 1},
    previewColors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
  ),
  AppEffect(
    id: 'rainbow_strobe',
    names: {'en': 'Rainbow Strobe', 'ru': 'Радужный стробоскоп', 'ua': 'Радужний стробоскоп'},
    driverEffectIds: {'ELK-BLEDOM': 146, 'SP110E': 2},
    previewColors: [Colors.red, Colors.green, Colors.blue],
  ),
  AppEffect(
    id: 'rainbow_chase',
    names: {'en': 'Rainbow Chase', 'ru': 'Радужная погоня', 'ua': 'Радужна погоня'},
    driverEffectIds: {'ELK-BLEDOM': 154, 'SP110E': 3},
    previewColors: [Colors.purple, Colors.blue, Colors.cyan],
  ),
  AppEffect(
    id: 'fire_glow',
    names: {'en': 'Fire Glow', 'ru': 'Пламя огня', 'ua': 'Полум\'я вогню'},
    driverEffectIds: {'ELK-BLEDOM': 131, 'SP110E': 4},
    previewColors: [Colors.red, Colors.orange, Colors.yellow],
  ),
  AppEffect(
    id: 'ice_cold',
    names: {'en': 'Ice Cold', 'ru': 'Холодный лед', 'ua': 'Холодний лід'},
    driverEffectIds: {'ELK-BLEDOM': 132, 'SP110E': 5},
    previewColors: [Colors.cyan, Colors.blue, Colors.white],
  ),
  AppEffect(
    id: 'forest_breath',
    names: {'en': 'Forest Breath', 'ru': 'Дыхание леса', 'ua': 'Дихання лісу'},
    driverEffectIds: {'ELK-BLEDOM': 129, 'SP110E': 6},
    previewColors: [Colors.green, Colors.lime, Colors.teal],
  ),
  AppEffect(
    id: 'sunset_fade',
    names: {'en': 'Sunset Fade', 'ru': 'Закатный градиент', 'ua': 'Західний градієнт'},
    driverEffectIds: {'ELK-BLEDOM': 133, 'SP110E': 7},
    previewColors: [Colors.pink, Colors.pinkAccent, Colors.orange],
  ),
  AppEffect(
    id: 'neon_night',
    names: {'en': 'Neon Cyberpunk', 'ru': 'Неоновый киберпанк', 'ua': 'Неоновий кіберпанк'},
    driverEffectIds: {'ELK-BLEDOM': 137, 'SP110E': 8},
    previewColors: [Colors.purpleAccent, Colors.blue, Colors.cyan],
  ),
  AppEffect(
    id: 'white_breath',
    names: {'en': 'White Breath', 'ru': 'Белое дыхание', 'ua': 'Біле дихання'},
    driverEffectIds: {'ELK-BLEDOM': 134, 'SP110E': 9},
    previewColors: [Colors.white, Colors.grey, Colors.white70],
  ),
  AppEffect(
    id: 'red_pulse',
    names: {'en': 'Red Pulse', 'ru': 'Красный пульс', 'ua': 'Червоний пульс'},
    driverEffectIds: {'ELK-BLEDOM': 128, 'SP110E': 10},
    previewColors: [Colors.red, Colors.redAccent],
  ),
  AppEffect(
    id: 'green_pulse',
    names: {'en': 'Green Pulse', 'ru': 'Зеленый пульс', 'ua': 'Зелений пульс'},
    driverEffectIds: {'ELK-BLEDOM': 129, 'SP110E': 11},
    previewColors: [Colors.green, Colors.greenAccent],
  ),
  AppEffect(
    id: 'blue_pulse',
    names: {'en': 'Blue Pulse', 'ru': 'Синий пульс', 'ua': 'Синій пульс'},
    driverEffectIds: {'ELK-BLEDOM': 130, 'SP110E': 12},
    previewColors: [Colors.blue, Colors.blueAccent],
  ),
  AppEffect(
    id: 'white_strobe',
    names: {'en': 'White Strobe', 'ru': 'Белый стробоскоп', 'ua': 'Білий стробоскоп'},
    driverEffectIds: {'ELK-BLEDOM': 145, 'SP110E': 13},
    previewColors: [Colors.white, Colors.white60],
  ),
  AppEffect(
    id: 'christmas',
    names: {'en': 'Christmas Holiday', 'ru': 'Новогодний перелив', 'ua': 'Новорічний перелив'},
    driverEffectIds: {'ELK-BLEDOM': 135, 'SP110E': 14},
    previewColors: [Colors.red, Colors.green],
  ),
  AppEffect(
    id: 'police',
    names: {'en': 'Police Siren', 'ru': 'Сирена полиции', 'ua': 'Сирена поліції'},
    driverEffectIds: {'ELK-BLEDOM': 136, 'SP110E': 15},
    previewColors: [Colors.red, Colors.blue],
  ),
  AppEffect(
    id: 'aurora',
    names: {'en': 'Aurora Borealis', 'ru': 'Полярное сияние', 'ua': 'Полярне сяйво'},
    driverEffectIds: {'ELK-BLEDOM': 139, 'SP110E': 16},
    previewColors: [Colors.deepPurple, Colors.teal, Colors.blue],
  ),
  AppEffect(
    id: 'sw_pulse',
    names: {'en': 'Software Pulse', 'ru': 'Программный пульс', 'ua': 'Програмний пульс'},
    driverEffectIds: {},
    previewColors: [Colors.white, Colors.black],
  ),
  AppEffect(
    id: 'sw_strobe',
    names: {'en': 'Software Strobe', 'ru': 'Программный строб', 'ua': 'Програмний строб'},
    driverEffectIds: {},
    previewColors: [Colors.white, Colors.red],
  ),
];

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

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  // ── Список обнаруженных при сканировании устройств ──
  final List<DiscoveredDevice> _discoveredDevices = [];
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  // ── Активные драйверы (установлены после успешного соединения) ──
  final Map<String, BaseLedDriver> _activeDrivers = {};
  Map<String, BaseLedDriver> get activeDrivers => _activeDrivers;

  final List<DiscoveredDevice> _connectedStrips = [];
  List<DiscoveredDevice> get connectedStrips => List.unmodifiable(_connectedStrips);

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

  // ── Software Effects ──
  Timer? _softwareEffectTimer;
  int _softwareEffectStep = 0;

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
            _state == DeviceManagerState.bleUnavailable ||
            _state == DeviceManagerState.idle) {
          _setState(DeviceManagerState.idle);
          
          if (_connectionHistory.isNotEmpty && !_isScanning && _activeDrivers.isEmpty) {
            startScan();
          }
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
    if (_isScanning) {
      debugPrint('[OmniLight/DeviceManager] Сканирование уже запущено');
      return;
    }

    // Очищаем предыдущие результаты
    _discoveredDevices.clear();
    _isScanning = true;
    if (_state != DeviceManagerState.connected && _state != DeviceManagerState.connecting) {
      _setState(DeviceManagerState.scanning);
    } else {
      notifyListeners();
    }

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
        // Автоматическое подключение к сохраненным устройствам
        for (final d in _discoveredDevices) {
          if (_connectionHistory.any((item) => item['id'] == d.device.remoteId.toString())) {
            connectToDevice(d);
          }
        }
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

    _isScanning = false;
    if (_state == DeviceManagerState.scanning) {
      if (_activeDrivers.isEmpty) {
        _setState(DeviceManagerState.idle);
      } else {
        _setState(DeviceManagerState.connected);
      }
    } else {
      notifyListeners();
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

      // Авто-подключение, если устройство есть в истории
      if (_connectionHistory.any((item) => item['id'] == result.device.remoteId.toString())) {
        connectToDevice(_discoveredDevices.last);
      }
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

    // Создаем НОВЫЙ экземпляр драйвера для этого конкретного подключения
    final driver = (discovered.matchedDriver is Sp110eDriver)
        ? Sp110eDriver()
        : ElkBledomDriver();
    _isConnecting = true;
    _setState(DeviceManagerState.connecting);

    try {
      await driver.connect(discovered.device);
      
      final id = discovered.device.remoteId.toString();
      _activeDrivers[id] = driver;
      
      // Добавляем в список подключенных лент
      _connectedStrips.removeWhere((d) => d.device.remoteId.toString() == id);
      _connectedStrips.add(discovered);
      
      _activeDriver = driver;
      _connectedDeviceName = discovered.name;
      _isConnecting = false;
      _setState(DeviceManagerState.connected);
      await _addToHistory(id, discovered.name);
      
      debugPrint(
        '[OmniLight/DeviceManager] Подключено: ${discovered.name} '
        'через ${driver.driverName} (всего подключено: ${_activeDrivers.length})',
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[OmniLight/DeviceManager] Ошибка подключения к ${discovered.name}: $e');
      _setError('Не удалось подключиться к ${discovered.name}: $e');
      if (_activeDrivers.isNotEmpty) {
        _setState(DeviceManagerState.connected);
      }
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
  // Отключить конкретное устройство
  // ─────────────────────────────────────────────
  Future<void> disconnectDevice(String id) async {
    final driver = _activeDrivers[id];
    if (driver != null) {
      try {
        await driver.disconnect();
      } catch (_) {}
      _activeDrivers.remove(id);
      _connectedStrips.removeWhere((d) => d.device.remoteId.toString() == id);
      if (_activeDrivers.isEmpty) {
        _activeDriver = null;
        _connectedDeviceName = null;
        _setState(DeviceManagerState.idle);
      } else {
        _activeDriver = _activeDrivers.values.last;
        _connectedDeviceName = _connectedStrips.last.name;
        notifyListeners();
      }
    }
  }

  // ─────────────────────────────────────────────
  // Отключиться от всех устройств
  // ─────────────────────────────────────────────
  Future<void> disconnectCurrent() async {
    _softwareEffectTimer?.cancel();
    for (final driver in _activeDrivers.values) {
      try {
        await driver.disconnect();
      } catch (_) {}
    }
    _activeDrivers.clear();
    _connectedStrips.clear();
    _activeDriver = null;
    _connectedDeviceName = null;
    _setState(DeviceManagerState.idle);
  }

  // ─────────────────────────────────────────────
  // Команда: установить цвет RGB (с сохранением состояния в UI)
  // ─────────────────────────────────────────────
  Future<void> setRgb(int r, int g, int b) async {
    _softwareEffectTimer?.cancel();
    _red = r;
    _green = g;
    _blue = b;
    notifyListeners();
    for (final driver in _activeDrivers.values) {
      try {
        await driver.setRgb(r, g, b);
      } catch (e) {
        debugPrint('[OmniLight/DeviceManager] Ошибка setRgb: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Команда: установить яркость
  // ─────────────────────────────────────────────
  Future<void> setBrightness(int level) async {
    _softwareEffectTimer?.cancel();
    _brightness = level.clamp(0, 255);
    notifyListeners();
    for (final driver in _activeDrivers.values) {
      try {
        await driver.setBrightness(_brightness);
      } catch (e) {
        debugPrint('[OmniLight/DeviceManager] Ошибка setBrightness: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Команда: включить
  // ─────────────────────────────────────────────
  Future<void> turnOn() async {
    _softwareEffectTimer?.cancel();
    for (final driver in _activeDrivers.values) {
      try {
        await driver.turnOn();
        // Восстанавливаем цвет и яркость
        await driver.setRgb(_red, _green, _blue);
        await driver.setBrightness(_brightness);
      } catch (e) {
        debugPrint('[OmniLight/DeviceManager] Ошибка turnOn: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Команда: выключить
  // ─────────────────────────────────────────────
  Future<void> turnOff() async {
    _softwareEffectTimer?.cancel();
    for (final driver in _activeDrivers.values) {
      try {
        await driver.turnOff();
        // Отправляем черный цвет в качестве надежного выключения
        await driver.setRgb(0, 0, 0);
      } catch (e) {
        debugPrint('[OmniLight/DeviceManager] Ошибка turnOff: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // Команда: установить динамический эффект
  // ─────────────────────────────────────────────
  Future<void> setEffect(String effectId, int speed) async {
    _softwareEffectTimer?.cancel();
    
    if (effectId.startsWith('sw_')) {
      _startSoftwareEffect(effectId, speed);
      return;
    }

    for (final driver in _activeDrivers.values) {
      try {
        final effect = appEffects.firstWhere((e) => e.id == effectId);
        final physicalId = effect.driverEffectIds[driver.driverName] ?? 1;
        await driver.setEffect(physicalId, speed);
      } catch (e) {
        debugPrint('[OmniLight/DeviceManager] Ошибка setEffect: $e');
      }
    }
  }

  void _startSoftwareEffect(String effectId, int speed) {
    final delay = max(30, 200 - speed).toInt();
    _softwareEffectStep = 0;
    
    _softwareEffectTimer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      _softwareEffectStep++;
      if (effectId == 'sw_pulse') {
        final val = ((sin(_softwareEffectStep * 0.2) + 1.0) / 2.0 * 255).toInt();
        for (final driver in _activeDrivers.values) {
          driver.setBrightness(val);
        }
      } else if (effectId == 'sw_strobe') {
        final val = (_softwareEffectStep % 2 == 0) ? 255 : 0;
        for (final driver in _activeDrivers.values) {
          driver.setBrightness(val);
        }
      }
    });
  }

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
    _softwareEffectTimer?.cancel();
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    for (final driver in _activeDrivers.values) {
      driver.disconnect();
    }
    super.dispose();
  }
}
