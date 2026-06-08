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
import 'package:home_widget/home_widget.dart';
import '../drivers/led_driver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Класс: AppEffect
// Назначение: Описание эффекта с поддержкой мультиязычности и кодов
//             эффектов для разных контроллеров.
// ─────────────────────────────────────────────────────────────────────────────
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

const List<AppEffect> appEffects = [
  // COLOR FLOW
  AppEffect(
    id: 'rainbow_flow',
    names: {'en': 'Rainbow Flow', 'ru': 'Радужный перелив', 'ua': 'Радужний перелив'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
  ),
  AppEffect(
    id: 'rainbow_chase',
    names: {'en': 'Rainbow Chase', 'ru': 'Радужная погоня', 'ua': 'Радужна погоня'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.purple, Colors.blue, Colors.cyan],
  ),
  AppEffect(
    id: 'sunset_fade',
    names: {'en': 'Sunset Fade', 'ru': 'Закатный градиент', 'ua': 'Західний градієнт'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.pink, Colors.pinkAccent, Colors.orange],
  ),
  AppEffect(
    id: 'pastel_flow',
    names: {'en': 'Pastel Flow', 'ru': 'Пастельный перелив', 'ua': 'Пастельний перелив'},
    category: EffectCategory.colorFlow,
    previewColors: [Color(0xFFFFB3BA), Color(0xFFFFDFBA), Color(0xFFFFFFBA), Color(0xFFBAFFC9), Color(0xFFBAE1FF)],
  ),
  AppEffect(
    id: 'toxic_flow',
    names: {'en': 'Toxic Flow', 'ru': 'Кислотный перелив', 'ua': 'Кислотний перелив'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.greenAccent, Colors.yellowAccent],
  ),
  AppEffect(
    id: 'neon_night',
    names: {'en': 'Neon Cyberpunk', 'ru': 'Неоновый киберпанк', 'ua': 'Неоновий кіберпанк'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.purpleAccent, Colors.blue, Colors.cyan],
  ),
  AppEffect(
    id: 'rgb_fade',
    names: {'en': 'RGB Fade', 'ru': 'Плавный RGB', 'ua': 'Плавний RGB'},
    category: EffectCategory.colorFlow,
    previewColors: [Colors.red, Colors.green, Colors.blue],
  ),

  // STROBE
  AppEffect(
    id: 'rainbow_strobe',
    names: {'en': 'Rainbow Strobe', 'ru': 'Радужный стробоскоп', 'ua': 'Радужний стробоскоп'},
    category: EffectCategory.strobe,
    previewColors: [Colors.red, Colors.green, Colors.blue],
  ),
  AppEffect(
    id: 'white_strobe',
    names: {'en': 'White Strobe', 'ru': 'Белый стробоскоп', 'ua': 'Білий стробоскоп'},
    category: EffectCategory.strobe,
    previewColors: [Colors.white, Colors.black],
  ),
  AppEffect(
    id: 'police_double',
    names: {'en': 'Police Double Strobe', 'ru': 'Двойной полицейский строб', 'ua': 'Подвійний поліцейський строб'},
    category: EffectCategory.strobe,
    previewColors: [Colors.red, Colors.blue],
  ),
  AppEffect(
    id: 'thunderstorm',
    names: {'en': 'Thunderstorm', 'ru': 'Гроза', 'ua': 'Гроза'},
    category: EffectCategory.strobe,
    previewColors: [Colors.deepPurple, Colors.white],
  ),
  AppEffect(
    id: 'neon_flash',
    names: {'en': 'Neon Flash', 'ru': 'Неоновые вспышки', 'ua': 'Неонові спалахи'},
    category: EffectCategory.strobe,
    previewColors: [Colors.pinkAccent, Colors.cyanAccent],
  ),

  // PULSING
  AppEffect(
    id: 'red_pulse',
    names: {'en': 'Red Pulse', 'ru': 'Красный пульс', 'ua': 'Червоний пульс'},
    category: EffectCategory.pulse,
    previewColors: [Colors.red, Colors.redAccent],
  ),
  AppEffect(
    id: 'green_pulse',
    names: {'en': 'Green Pulse', 'ru': 'Зеленый пульс', 'ua': 'Зелений пульс'},
    category: EffectCategory.pulse,
    previewColors: [Colors.green, Colors.greenAccent],
  ),
  AppEffect(
    id: 'blue_pulse',
    names: {'en': 'Blue Pulse', 'ru': 'Синий пульс', 'ua': 'Синій пульс'},
    category: EffectCategory.pulse,
    previewColors: [Colors.blue, Colors.blueAccent],
  ),
  AppEffect(
    id: 'white_breath',
    names: {'en': 'White Breath', 'ru': 'Белое дыхание', 'ua': 'Біле дихання'},
    category: EffectCategory.pulse,
    previewColors: [Colors.white, Colors.grey],
  ),
  AppEffect(
    id: 'heartbeat',
    names: {'en': 'Heartbeat', 'ru': 'Сердцебиение', 'ua': 'Серцебиття'},
    category: EffectCategory.pulse,
    previewColors: [Colors.red, Colors.black],
  ),

  // NATURE
  AppEffect(
    id: 'fire_glow',
    names: {'en': 'Fire Glow', 'ru': 'Пламя огня', 'ua': 'Полум\'я вогню'},
    category: EffectCategory.nature,
    previewColors: [Colors.red, Colors.orange, Colors.yellow],
  ),
  AppEffect(
    id: 'ice_cold',
    names: {'en': 'Ice Cold', 'ru': 'Холодный лед', 'ua': 'Холодний лід'},
    category: EffectCategory.nature,
    previewColors: [Colors.cyan, Colors.blue, Colors.white],
  ),
  AppEffect(
    id: 'forest_breath',
    names: {'en': 'Forest Breath', 'ru': 'Дыхание леса', 'ua': 'Дихання лісу'},
    category: EffectCategory.nature,
    previewColors: [Colors.green, Colors.lime, Colors.teal],
  ),
  AppEffect(
    id: 'aurora',
    names: {'en': 'Aurora Borealis', 'ru': 'Полярное сияние', 'ua': 'Полярне сяйво'},
    category: EffectCategory.nature,
    previewColors: [Colors.deepPurple, Colors.teal, Colors.blue],
  ),

  // SPECIAL
  AppEffect(
    id: 'police',
    names: {'en': 'Police Siren', 'ru': 'Сирена полиции', 'ua': 'Сирена поліції'},
    category: EffectCategory.special,
    previewColors: [Colors.red, Colors.blue],
  ),
  AppEffect(
    id: 'christmas',
    names: {'en': 'Christmas Holiday', 'ru': 'Новогодний перелив', 'ua': 'Новорічний перелив'},
    category: EffectCategory.special,
    previewColors: [Colors.red, Colors.green],
  ),
  AppEffect(
    id: 'gold_rush',
    names: {'en': 'Gold Rush', 'ru': 'Золотая лихорадка', 'ua': 'Золота лихоманка'},
    category: EffectCategory.special,
    previewColors: [Color(0xFFFFD700), Color(0xFFDAA520)],
  ),
  AppEffect(
    id: 'valentine',
    names: {'en': 'Valentine', 'ru': 'День Святого Валентина', 'ua': 'День Святого Валентина'},
    category: EffectCategory.special,
    previewColors: [Colors.pink, Colors.redAccent],
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
  String? _currentEffectId;
  String? get currentEffectId => _currentEffectId;
  final Random _random = Random();

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
      _updateConnectionStatus();
    } catch (e) {
      _isConnecting = false;
      debugPrint('[OmniLight/DeviceManager] Ошибка подключения к ${discovered.name}: $e');
      _setError('Не удалось подключиться к ${discovered.name}: $e');
      if (_activeDrivers.isNotEmpty) {
        _setState(DeviceManagerState.connected);
      }
      _updateConnectionStatus();
    }
  }

  void _updateConnectionStatus() {
    bool hasConnected = false;
    for (var driver in _activeDrivers.values) {
      if (driver.state == DriverState.connected) {
        hasConnected = true;
        break;
      }
    }
    
    _updateHomeWidgetStatus(hasConnected);
    notifyListeners();
  }

  Future<void> _updateHomeWidgetStatus(bool hasConnected) async {
    try {
      final status = hasConnected ? "Подключено: ${connectedStrips.length}" : "Отключено";
      await HomeWidget.saveWidgetData<String>('widget_status', status);
      await HomeWidget.updateWidget(
        name: 'HomeWidgetProvider',
        iOSName: 'OmniLightWidget',
      );
    } catch (e) {
      debugPrint("Error updating widget: \$e");
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
      _updateConnectionStatus();
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
    _updateConnectionStatus();
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
  // Установка эффекта
  // ─────────────────────────────────────────────
  Future<void> setEffect(String effectId, int speed) async {
    _softwareEffectTimer?.cancel();
    _currentEffectId = effectId;
    _startSoftwareEffect(effectId, speed);
  }

  void updateEffectSpeed(int speed) {
    if (_currentEffectId != null) {
      setEffect(_currentEffectId!, speed);
    }
  }

  void _startSoftwareEffect(String effectId, int speed) {
    // Длительность шага таймера от 20мс до 150мс в зависимости от ползунка скорости (1..100)
    final delay = max(20, 150 - speed).toInt();
    _softwareEffectStep = 0;
    
    _softwareEffectTimer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      _softwareEffectStep++;
      int r = 0, g = 0, b = 0;
      
      switch (effectId) {
        case 'rainbow_flow':
        case 'rainbow_chase':
        case 'rainbow_strobe':
          final h = (_softwareEffectStep * 5.0) % 360.0;
          final rgb = HSVColor.fromAHSV(1.0, h, 1.0, 1.0).toColor();
          r = (rgb.r * 255.0).round().clamp(0, 255); 
          g = (rgb.g * 255.0).round().clamp(0, 255); 
          b = (rgb.b * 255.0).round().clamp(0, 255);
          if (effectId == 'rainbow_strobe' && _softwareEffectStep % 2 == 0) {
            r = 0; g = 0; b = 0;
          }
          break;

        case 'pastel_flow':
          final h = (_softwareEffectStep * 3.0) % 360.0;
          final rgb = HSVColor.fromAHSV(1.0, h, 0.4, 1.0).toColor();
          r = (rgb.r * 255.0).round().clamp(0, 255); 
          g = (rgb.g * 255.0).round().clamp(0, 255); 
          b = (rgb.b * 255.0).round().clamp(0, 255);
          break;

        case 'toxic_flow':
          final val = (sin(_softwareEffectStep * 0.2) + 1) / 2.0;
          r = (val * 100).toInt();
          g = 255;
          b = ((1 - val) * 100).toInt();
          break;

        case 'rgb_fade':
          final phase = (_softwareEffectStep * 0.1) % (pi * 2);
          r = (((sin(phase) + 1) / 2.0) * 255).toInt();
          g = (((sin(phase + (pi * 2 / 3)) + 1) / 2.0) * 255).toInt();
          b = (((sin(phase + (pi * 4 / 3)) + 1) / 2.0) * 255).toInt();
          break;
          
        case 'fire_glow':
          final val = (sin(_softwareEffectStep * 0.3) + 1) / 2.0; 
          r = 255;
          g = (val * 165).toInt(); 
          b = 0;
          break;
          
        case 'ice_cold':
          final val = (sin(_softwareEffectStep * 0.2) + 1) / 2.0;
          r = (val * 100).toInt();
          g = 255;
          b = 255;
          break;
          
        case 'forest_breath':
          final val = (sin(_softwareEffectStep * 0.15) + 1) / 2.0;
          r = 0;
          g = (155 + val * 100).toInt();
          b = (val * 50).toInt();
          break;
          
        case 'neon_night':
        case 'aurora':
          final val = (sin(_softwareEffectStep * 0.1) + 1) / 2.0;
          r = ((1 - val) * 200).toInt();
          g = (val * 200).toInt();
          b = 255;
          break;
          
        case 'police':
          final step = _softwareEffectStep % 8;
          if (step < 2) { r = 255; g = 0; b = 0; }
          else if (step < 4) { r = 0; g = 0; b = 0; }
          else if (step < 6) { r = 0; g = 0; b = 255; }
          else { r = 0; g = 0; b = 0; }
          break;

        case 'police_double':
          final step = _softwareEffectStep % 16;
          if (step == 0 || step == 2) { r = 255; g = 0; b = 0; }
          else if (step == 8 || step == 10) { r = 0; g = 0; b = 255; }
          else { r = 0; g = 0; b = 0; }
          break;

        case 'thunderstorm':
          if (_random.nextDouble() > 0.95) { r = 255; g = 255; b = 255; }
          else { r = 20; g = 0; b = 40; } // deep purple background
          break;

        case 'neon_flash':
          if (_softwareEffectStep % 3 == 0) {
            final h = _random.nextDouble() * 360.0;
            final rgb = HSVColor.fromAHSV(1.0, h, 1.0, 1.0).toColor();
            r = (rgb.r * 255.0).round().clamp(0, 255); 
            g = (rgb.g * 255.0).round().clamp(0, 255); 
            b = (rgb.b * 255.0).round().clamp(0, 255);
          } else {
            r = 0; g = 0; b = 0;
          }
          break;

        case 'heartbeat':
          final step = _softwareEffectStep % 10;
          if (step == 0 || step == 2) { r = 255; g = 0; b = 0; }
          else { r = 10; g = 0; b = 0; }
          break;

        case 'christmas':
          final step = _softwareEffectStep % 4;
          if (step < 2) { r = 255; g = 0; b = 0; }
          else { r = 0; g = 255; b = 0; }
          break;

        case 'gold_rush':
          final val = (sin(_softwareEffectStep * 0.2) + 1) / 2.0;
          r = 255;
          g = (215 - val * 50).toInt();
          b = 0;
          break;

        case 'valentine':
          final val = (sin(_softwareEffectStep * 0.15) + 1) / 2.0;
          r = 255;
          g = (val * 100).toInt();
          b = (val * 150).toInt();
          break;

        case 'white_strobe':
        case 'sw_strobe':
          final val = (_softwareEffectStep % 2 == 0) ? 255 : 0;
          r = val; g = val; b = val;
          break;

        case 'white_breath':
        case 'sw_pulse':
          final val = (((sin(_softwareEffectStep * 0.1) + 1) / 2.0) * 255).toInt();
          r = val; g = val; b = val;
          break;

        case 'red_pulse':
          final val = (((sin(_softwareEffectStep * 0.1) + 1) / 2.0) * 255).toInt();
          r = val; g = 0; b = 0;
          break;

        case 'green_pulse':
          final val = (((sin(_softwareEffectStep * 0.1) + 1) / 2.0) * 255).toInt();
          r = 0; g = val; b = 0;
          break;

        case 'blue_pulse':
          final val = (((sin(_softwareEffectStep * 0.1) + 1) / 2.0) * 255).toInt();
          r = 0; g = 0; b = val;
          break;

        case 'sunset_fade':
          final val = (sin(_softwareEffectStep * 0.05) + 1) / 2.0;
          r = 255;
          g = (val * 128).toInt();
          b = ((1 - val) * 128).toInt();
          break;

        default:
          r = 255; g = 255; b = 255;
      }
      
      // Отправляем цвет сразу на все ленты
      for (final driver in _activeDrivers.values) {
        driver.setRgb(r, g, b);
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
