// ============================================================
// OmniLight by Abstrackt
// Файл: main_screen.dart
// Назначение: Главный экран приложения. Реализует полный UI:
//               - Шапка с названием и кнопкой настроек
//               - Статус-бар подключения (с анимацией)
//               - Список найденных устройств (во время сканирования)
//               - Интерактивный HSV цветовой пикер
//               - Слайдер яркости
//               - Быстрые пресеты цветов
//               - Кнопки Turn ON / Turn OFF
//               - Модальный лист настроек (язык + тема)
//
//             Использует:
//               - iOS Haptic Feedback для тактильного отклика
//               - 50ms debounce на цветовой пикер (предотвращает BLE-флуд)
//               - AnimatedContainer и AnimatedOpacity для плавных переходов
//               - Кибер-неоновое свечение через BoxDecoration с boxShadow
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../core/localization_theme_store.dart';
import '../core/device_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Константы: базовые пресеты цветов
// ─────────────────────────────────────────────────────────────────────────────
class _ColorPreset {
  final String labelKey; // Ключ локализации
  final Color color;
  final IconData icon;

  const _ColorPreset({
    required this.labelKey,
    required this.color,
    required this.icon,
  });
}

const List<_ColorPreset> _presets = [
  _ColorPreset(
    labelKey: 'preset_red',
    color: Color(0xFFFF2D55),
    icon: Icons.circle,
  ),
  _ColorPreset(
    labelKey: 'preset_green',
    color: Color(0xFF34C759),
    icon: Icons.circle,
  ),
  _ColorPreset(
    labelKey: 'preset_blue',
    color: Color(0xFF007AFF),
    icon: Icons.circle,
  ),
  _ColorPreset(
    labelKey: 'preset_white',
    color: Color(0xFFFFFFFF),
    icon: Icons.circle,
  ),
  _ColorPreset(
    labelKey: 'preset_warm',
    color: Color(0xFFFF9F0A),
    icon: Icons.circle,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: MainScreen
// Назначение: Основной StatefulWidget с полным UI управления OmniLight.
// ─────────────────────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // ── Текущий цвет в пикере ──
  Color _pickerColor = const Color(0xFF007AFF);

  // ── Debounce таймер для отправки BLE-команд (50ms) ──
  Timer? _colorDebounceTimer;

  // ── Анимации ──
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _scanRingController;
  late final Animation<double> _scanRingAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация пульсации статус-индикатора при подключении
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Анимация вращающегося кольца во время сканирования
    _scanRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanRingAnimation = CurvedAnimation(
      parent: _scanRingController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _colorDebounceTimer?.cancel();
    _pulseController.dispose();
    _scanRingController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Haptic Feedback: тактильный отклик iOS
  // ─────────────────────────────────────────────

  /// Средний haptic (при подключении)
  void _hapticMedium() {
    HapticFeedback.mediumImpact();
  }

  /// Лёгкий haptic (пресеты, переключатели)
  void _hapticLight() {
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────
  // Обработчик изменения цвета с debounce 50ms
  // Предотвращает перегрузку стека iOS CoreBluetooth
  // ─────────────────────────────────────────────
  void _onColorChanged(Color color) {
    setState(() => _pickerColor = color);

    // Отменяем предыдущий таймер, если пользователь продолжает двигать
    _colorDebounceTimer?.cancel();

    // Создаём новый таймер с задержкой 50ms
    _colorDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      final manager = context.read<DeviceManager>();
      if (manager.state == DeviceManagerState.connected) {
        manager.setRgb(
          (color.r * 255.0).round().clamp(0, 255),
          (color.g * 255.0).round().clamp(0, 255),
          (color.b * 255.0).round().clamp(0, 255),
        );
      }
    });
  }

  // ─────────────────────────────────────────────
  // Применить пресет цвета
  // ─────────────────────────────────────────────
  Future<void> _applyPreset(_ColorPreset preset) async {
    _hapticLight();
    setState(() => _pickerColor = preset.color);
    final manager = context.read<DeviceManager>();
    if (manager.state == DeviceManagerState.connected) {
      await manager.setRgb(
        (preset.color.r * 255.0).round().clamp(0, 255),
        (preset.color.g * 255.0).round().clamp(0, 255),
        (preset.color.b * 255.0).round().clamp(0, 255),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Открыть модальный лист настроек (язык + тема)
  // ─────────────────────────────────────────────
  void _openSettings() {
    _hapticLight();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SettingsSheet(),
    );
  }

  // ─────────────────────────────────────────────
  // Открыть модальный лист поддержки и FAQ
  // ─────────────────────────────────────────────
  void _openSupport() {
    _hapticLight();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SupportSheet(),
    );
  }

  // ─────────────────────────────────────────────
  // Построение строки статуса подключения
  // ─────────────────────────────────────────────
  String _buildStatusText(
    DeviceManagerState state,
    String? deviceName,
    String? errorMessage,
    LocalizationThemeStore store,
  ) {
    switch (state) {
      case DeviceManagerState.scanning:
        return store.tr('status_scanning');
      case DeviceManagerState.connecting:
        return store.tr('status_connecting');
      case DeviceManagerState.connected:
        return '${store.tr("status_connected")} ${deviceName ?? ""}';
      case DeviceManagerState.bleOff:
        return store.tr('ble_off');
      case DeviceManagerState.bleUnavailable:
        return store.tr('ble_unavailable');
      case DeviceManagerState.permissionDenied:
        return store.tr('ble_permission_denied');
      case DeviceManagerState.error:
        return errorMessage != null
            ? '${store.tr('status_error')}: $errorMessage'
            : store.tr('status_error');
      case DeviceManagerState.idle:
        return store.tr('status_disconnected');
    }
  }

  // ─────────────────────────────────────────────
  // Цвет статус-индикатора по состоянию
  // ─────────────────────────────────────────────
  Color _statusColor(DeviceManagerState state, AppThemeData themeData) {
    switch (state) {
      case DeviceManagerState.connected:
        return const Color(0xFF34C759); // iOS зелёный
      case DeviceManagerState.scanning:
      case DeviceManagerState.connecting:
        return themeData.accentPrimary;
      case DeviceManagerState.error:
      case DeviceManagerState.permissionDenied:
        return const Color(0xFFFF3B30); // iOS красный
      default:
        return const Color(0xFF8E8E93); // iOS серый
    }
  }

  // ─────────────────────────────────────────────
  // BUILD: главный экран
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalizationThemeStore>();
    final manager = context.watch<DeviceManager>();
    final themeData = store.currentThemeData;
    final isConnected = manager.state == DeviceManagerState.connected;
    final isScanning = manager.state == DeviceManagerState.scanning;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          // BouncingScrollPhysics — только iOS; на Web/Desktop используем ClampingScrollPhysics
          physics: kIsWeb
              ? const ClampingScrollPhysics()
              : const BouncingScrollPhysics(),
          slivers: [
            // ════════════════════════════════════════
            // Шапка: OmniLight by Abstrackt + кнопка настроек
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildHeader(store, themeData),
            ),

            // ════════════════════════════════════════
            // Статус-бар подключения
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildStatusBar(store, manager, themeData),
            ),

            // ════════════════════════════════════════
            // Список найденных устройств (во время сканирования)
            // ════════════════════════════════════════
            if (isScanning || manager.discoveredDevices.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildDeviceList(store, manager, themeData),
              ),

            // ════════════════════════════════════════
            // Кнопки управления (Scan / Disconnect)
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: _buildConnectionControls(store, manager, themeData),
            ),

            // ════════════════════════════════════════
            // Цветовой пикер HSV (только при подключении)
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: _buildColorPicker(store, themeData, isConnected),
              ),
            ),

            // ════════════════════════════════════════
            // Слайдер яркости
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: _buildBrightnessSlider(store, manager, themeData, isConnected),
              ),
            ),

            // ════════════════════════════════════════
            // Быстрые пресеты цветов
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: _buildPresets(store, themeData, isConnected),
              ),
            ),

            // ════════════════════════════════════════
            // Кнопки Turn ON / Turn OFF
            // ════════════════════════════════════════
            SliverToBoxAdapter(
              child: AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 300),
                child: _buildPowerButtons(store, manager, themeData, isConnected),
              ),
            ),

            // Нижний отступ для iOS Home Indicator
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Шапка приложения
  // ─────────────────────────────────────────────
  Widget _buildHeader(LocalizationThemeStore store, AppThemeData themeData) {
    final isCyber = store.appTheme == AppTheme.cyberNeon;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          // Логотип / иконка
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCyber
                    ? [themeData.accentPrimary, themeData.accentSecondary]
                    : [themeData.accentPrimary, themeData.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isCyber
                  ? [
                      BoxShadow(
                        color: themeData.glowColor.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Заголовок
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название приложения с опциональным неоновым свечением
                Text(
                  store.tr('app_title'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: themeData.themeData.colorScheme.onSurface,
                    shadows: isCyber
                        ? [
                            Shadow(
                              color: themeData.accentPrimary.withValues(alpha: 0.8),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                ),
                Text(
                  store.tr('app_subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: themeData.accentPrimary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    shadows: isCyber
                        ? [
                            Shadow(
                              color: themeData.accentSecondary.withValues(alpha: 0.9),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Кнопка поддержки
          _GlowIconButton(
            icon: Icons.help_outline_rounded,
            themeData: themeData,
            onTap: _openSupport,
            tooltip: store.tr('support_title'),
          ),
          const SizedBox(width: 8),

          // Кнопка настроек
          _GlowIconButton(
            icon: Icons.tune_rounded,
            themeData: themeData,
            onTap: _openSettings,
            tooltip: store.tr('settings_title'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Статус-бар подключения
  // ─────────────────────────────────────────────
  Widget _buildStatusBar(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final statusColor = _statusColor(manager.state, themeData);
    final statusText = _buildStatusText(
      manager.state,
      manager.connectedDeviceName,
      manager.errorMessage,
      store,
    );
    final isScanning = manager.state == DeviceManagerState.scanning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: themeData.hasGlow
              ? [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Анимированный статус-индикатор
            if (isScanning)
              SizedBox(
                width: 16,
                height: 16,
                child: RotationTransition(
                  turns: _scanRingAnimation,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
              )
            else
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Opacity(
                  opacity: manager.state == DeviceManagerState.connected
                      ? _pulseAnimation.value
                      : 1.0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Имя драйвера (если подключено)
            if (manager.state == DeviceManagerState.connected &&
                manager.activeDriver != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: themeData.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  manager.activeDriver!.driverName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: themeData.accentPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Список найденных устройств
  // ─────────────────────────────────────────────
  Widget _buildDeviceList(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              store.tr('select_device'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: themeData.accentPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (manager.discoveredDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  store.tr('no_devices_found'),
                  style: TextStyle(
                    color: themeData.themeData.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            ...manager.discoveredDevices.map(
              (d) => _DeviceTile(
                discovered: d,
                themeData: themeData,
                onTap: () async {
                  _hapticMedium();
                  await manager.connectToDevice(d);
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Кнопки Scan / Disconnect
  // ─────────────────────────────────────────────
  Widget _buildConnectionControls(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isConnected = manager.state == DeviceManagerState.connected;
    final isScanning = manager.state == DeviceManagerState.scanning;
    final isConnecting = manager.state == DeviceManagerState.connecting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Кнопка Сканировать / Остановить
          Expanded(
            child: _NeonButton(
              label: isScanning
                  ? store.tr('btn_disconnect') // "Стоп"
                  : store.tr('btn_scan'),
              icon: isScanning ? Icons.stop_rounded : Icons.bluetooth_searching_rounded,
              themeData: themeData,
              isLoading: isConnecting,
              enabled: !isConnected && !isConnecting,
              isPrimary: true,
              onTap: () async {
                _hapticLight();
                if (isScanning) {
                  await manager.stopScan();
                } else {
                  await manager.startScan();
                }
              },
            ),
          ),

          if (isConnected) ...[
            const SizedBox(width: 12),
            // Кнопка Отключить
            Expanded(
              child: _NeonButton(
                label: store.tr('btn_disconnect'),
                icon: Icons.bluetooth_disabled_rounded,
                themeData: themeData,
                isLoading: false,
                enabled: true,
                isPrimary: false,
                onTap: () async {
                  _hapticMedium();
                  await manager.disconnectCurrent();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Цветовой пикер (HSV колесо + слайдер тона)
  // ─────────────────────────────────────────────
  Widget _buildColorPicker(
    LocalizationThemeStore store,
    AppThemeData themeData,
    bool isConnected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: themeData.hasGlow
              ? [
                  BoxShadow(
                    color: _pickerColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            // Заголовок пикера
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.palette_rounded,
                    color: themeData.accentPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    store.tr('color_picker_label'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeData.themeData.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Превью выбранного цвета
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _pickerColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _pickerColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // HSV колесо
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: ColorPicker(
                    pickerColor: _pickerColor,
                    onColorChanged: isConnected ? _onColorChanged : (_) {},
                    colorPickerWidth: 320,
                    pickerAreaHeightPercent: 0.75,
                    enableAlpha: false,
                    displayThumbColor: true,
                    paletteType: PaletteType.hsv,
                    labelTypes: const [],
                    pickerAreaBorderRadius: BorderRadius.circular(12),
                    portraitOnly: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Слайдер яркости
  // ─────────────────────────────────────────────
  Widget _buildBrightnessSlider(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
    bool isConnected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.brightness_6_rounded,
                  color: themeData.accentPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  store.tr('brightness_label'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: themeData.themeData.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Процентное значение яркости
                Text(
                  '${(manager.brightness / 255 * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: themeData.accentPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: themeData.accentPrimary,
                inactiveTrackColor: themeData.accentPrimary.withValues(alpha: 0.2),
                thumbColor: themeData.accentPrimary,
                overlayColor: themeData.accentPrimary.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                trackHeight: 4,
              ),
              child: Slider(
                value: manager.brightness.toDouble(),
                min: 0,
                max: 255,
                onChanged: isConnected
                    ? (val) {
                        _hapticLight();
                        manager.setBrightness(val.round());
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Быстрые пресеты цветов
  // ─────────────────────────────────────────────
  Widget _buildPresets(
    LocalizationThemeStore store,
    AppThemeData themeData,
    bool isConnected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Presets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Row(
            children: _presets
                .map(
                  (preset) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _PresetChip(
                        preset: preset,
                        label: store.tr(preset.labelKey),
                        themeData: themeData,
                        isSelected: _pickerColor.toARGB32() == preset.color.toARGB32(),
                        enabled: isConnected,
                        onTap: () => _applyPreset(preset),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Кнопки Turn ON / Turn OFF
  // ─────────────────────────────────────────────
  Widget _buildPowerButtons(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
    bool isConnected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Turn ON
          Expanded(
            child: _NeonButton(
              label: store.tr('btn_turn_on'),
              icon: Icons.power_settings_new_rounded,
              themeData: themeData,
              isLoading: false,
              enabled: isConnected,
              isPrimary: true,
              onTap: () async {
                _hapticMedium();
                await manager.turnOn();
              },
            ),
          ),
          const SizedBox(width: 12),
          // Turn OFF
          Expanded(
            child: _NeonButton(
              label: store.tr('btn_turn_off'),
              icon: Icons.power_off_rounded,
              themeData: themeData,
              isLoading: false,
              enabled: isConnected,
              isPrimary: false,
              onTap: () async {
                _hapticMedium();
                await manager.turnOff();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _GlowIconButton
// Назначение: Иконочная кнопка с опциональным неоновым свечением
// ─────────────────────────────────────────────────────────────────────────────
class _GlowIconButton extends StatelessWidget {
  final IconData icon;
  final AppThemeData themeData;
  final VoidCallback onTap;
  final String tooltip;

  const _GlowIconButton({
    required this.icon,
    required this.themeData,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: themeData.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: themeData.hasGlow
                ? [
                    BoxShadow(
                      color: themeData.accentPrimary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            size: 22,
            color: themeData.accentPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _NeonButton
// Назначение: Унифицированная кнопка с поддержкой всех трёх тем.
//             В режиме Cyber Neon отображается с обводкой и свечением.
// ─────────────────────────────────────────────────────────────────────────────
class _NeonButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final AppThemeData themeData;
  final bool isLoading;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NeonButton({
    required this.label,
    required this.icon,
    required this.themeData,
    required this.isLoading,
    required this.enabled,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<_NeonButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isCyber = widget.themeData.hasGlow;
    final accentColor = widget.isPrimary
        ? widget.themeData.accentPrimary
        : widget.themeData.accentSecondary;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.enabled && !widget.isLoading ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.96 : 1.0,
          _pressed ? 0.96 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          // Заливка или прозрачность (Cyber Neon)
          color: isCyber
              ? (widget.enabled ? accentColor.withValues(alpha: 0.1) : Colors.transparent)
              : (widget.isPrimary
                  ? (widget.enabled ? accentColor : accentColor.withValues(alpha: 0.4))
                  : widget.themeData.cardColor),
          borderRadius: BorderRadius.circular(14),
          border: isCyber
              ? Border.all(
                  color: widget.enabled
                      ? accentColor
                      : accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: isCyber && widget.enabled
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(accentColor),
                ),
              )
            else
              Icon(
                widget.icon,
                size: 18,
                color: isCyber
                    ? accentColor
                    : (widget.isPrimary ? Colors.white : accentColor),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isCyber
                      ? accentColor
                      : (widget.isPrimary ? Colors.white : accentColor),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _PresetChip
// Назначение: Цветовой чип пресета с анимацией выбора
// ─────────────────────────────────────────────────────────────────────────────
class _PresetChip extends StatelessWidget {
  final _ColorPreset preset;
  final String label;
  final AppThemeData themeData;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.label,
    required this.themeData,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? preset.color.withValues(alpha: 0.2)
              : themeData.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? preset.color : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: preset.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: enabled ? preset.color : preset.color.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: preset.color.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: themeData.themeData.colorScheme.onSurface
                    .withValues(alpha: enabled ? 0.8 : 0.4),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _DeviceTile
// Назначение: Строка найденного BLE-устройства в списке сканирования.
//             Показывает имя, RSSI и иконку совместимого протокола.
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final DiscoveredDevice discovered;
  final AppThemeData themeData;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.discovered,
    required this.themeData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSupported = discovered.matchedDriver != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: themeData.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: isSupported
              ? Border.all(
                  color: themeData.accentPrimary.withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // BLE иконка
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSupported
                    ? themeData.accentPrimary.withValues(alpha: 0.15)
                    : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bluetooth_rounded,
                color: isSupported
                    ? themeData.accentPrimary
                    : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discovered.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: themeData.themeData.colorScheme.onSurface,
                    ),
                  ),
                  if (isSupported)
                    Text(
                      discovered.matchedDriver!.driverName,
                      style: TextStyle(
                        fontSize: 11,
                        color: themeData.accentPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            // Уровень сигнала RSSI
            Column(
              children: [
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 16,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                Text(
                  '${discovered.rssi}',
                  style: TextStyle(
                    fontSize: 10,
                    color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: _SettingsSheet
// Назначение: Модальный лист настроек (тема + язык).
//             Открывается через showModalBottomSheet с закруглёнными углами.
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalizationThemeStore>();
    final themeData = store.currentThemeData;

    return Container(
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: themeData.hasGlow
            ? [
                BoxShadow(
                  color: themeData.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ]
            : [],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Индикатор перетаскивания
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              // Заголовок
              Text(
                store.tr('settings_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // Брендированный блок
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeData.accentPrimary.withValues(alpha: 0.15),
                      themeData.accentSecondary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeData.accentPrimary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: themeData.glowColor.withValues(alpha: 0.45),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OmniLight',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: themeData.themeData.colorScheme.onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BY ABSTRACKT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Выбор темы ──
              _SettingsSection(
                label: store.tr('settings_theme'),
                themeData: themeData,
                child: Row(
                  children: [
                    _ThemeButton(
                      label: store.tr('theme_light'),
                      icon: Icons.light_mode_outlined,
                      isSelected: store.appTheme == AppTheme.light,
                      themeData: themeData,
                      onTap: () => store.setTheme(AppTheme.light),
                    ),
                    const SizedBox(width: 8),
                    _ThemeButton(
                      label: store.tr('theme_dark'),
                      icon: Icons.dark_mode_outlined,
                      isSelected: store.appTheme == AppTheme.dark,
                      themeData: themeData,
                      onTap: () => store.setTheme(AppTheme.dark),
                    ),
                    const SizedBox(width: 8),
                    _ThemeButton(
                      label: store.tr('theme_cyber'),
                      icon: Icons.auto_awesome_outlined,
                      isSelected: store.appTheme == AppTheme.cyberNeon,
                      themeData: themeData,
                      onTap: () => store.setTheme(AppTheme.cyberNeon),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Выбор языка ──
              _SettingsSection(
                label: store.tr('settings_language'),
                themeData: themeData,
                child: Row(
                  children: [
                    _LangButton(
                      code: 'EN',
                      isSelected: store.language == AppLanguage.en,
                      themeData: themeData,
                      onTap: () => store.setLanguage(AppLanguage.en),
                    ),
                    const SizedBox(width: 8),
                    _LangButton(
                      code: 'RU',
                      isSelected: store.language == AppLanguage.ru,
                      themeData: themeData,
                      onTap: () => store.setLanguage(AppLanguage.ru),
                    ),
                    const SizedBox(width: 8),
                    _LangButton(
                      code: 'UA',
                      isSelected: store.language == AppLanguage.ua,
                      themeData: themeData,
                      onTap: () => store.setLanguage(AppLanguage.ua),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Секция настроек с заголовком и содержимым
class _SettingsSection extends StatelessWidget {
  final String label;
  final AppThemeData themeData;
  final Widget child;

  const _SettingsSection({
    required this.label,
    required this.themeData,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: themeData.accentPrimary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// Кнопка выбора темы
class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final AppThemeData themeData;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.themeData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? themeData.accentPrimary.withValues(alpha: 0.15)
                : themeData.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? themeData.accentPrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? themeData.accentPrimary
                    : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? themeData.accentPrimary
                      : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Кнопка выбора языка
class _LangButton extends StatelessWidget {
  final String code;
  final bool isSelected;
  final AppThemeData themeData;
  final VoidCallback onTap;

  const _LangButton({
    required this.code,
    required this.isSelected,
    required this.themeData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? themeData.accentPrimary.withValues(alpha: 0.15)
                : themeData.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? themeData.accentPrimary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected && themeData.hasGlow
                ? [
                    BoxShadow(
                      color: themeData.accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? themeData.accentPrimary
                  : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: _SupportSheet
// Назначение: Модальный лист поддержки, содержащий FAQ и историю подключений.
// ─────────────────────────────────────────────────────────────────────────────
class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalizationThemeStore>();
    final manager = context.watch<DeviceManager>();
    final themeData = store.currentThemeData;
    final lang = store.language;

    // Функция перевода
    String t(Map<AppLanguage, String> map) => map[lang] ?? map[AppLanguage.en]!;

    // Заголовки разделов
    final historyTitle = t({
      AppLanguage.en: 'Connection History',
      AppLanguage.ru: 'История подключений',
      AppLanguage.ua: 'Історія підключень',
    });

    final faqTitle = t({
      AppLanguage.en: 'Frequently Asked Questions',
      AppLanguage.ru: 'Часто задаваемые вопросы',
      AppLanguage.ua: 'Часті запитання',
    });

    final emptyHistoryMsg = t({
      AppLanguage.en: 'No saved devices. Connect to a strip on the main screen to save it here.',
      AppLanguage.ru: 'История подключений пуста. Подключитесь к ленте на главном экране, и она сохранится здесь.',
      AppLanguage.ua: 'Історія підключень пуста. Підключіться до стрічки на головному екрані, и вона збережеться тут.',
    });

    final connectBtnText = t({
      AppLanguage.en: 'Connect',
      AppLanguage.ru: 'Подключить',
      AppLanguage.ua: 'Підключити',
    });

    final connectedStatusText = t({
      AppLanguage.en: 'Connected',
      AppLanguage.ru: 'Подключено',
      AppLanguage.ua: 'Підключено',
    });

    final clearHistoryText = t({
      AppLanguage.en: 'Clear History',
      AppLanguage.ru: 'Очистить историю',
      AppLanguage.ua: 'Очистити історію',
    });

    final faqs = [
      {
        'q': {
          AppLanguage.en: 'Why is my LED strip not showing up in the scan list?',
          AppLanguage.ru: 'Почему лента не отображается в списке сканирования?',
          AppLanguage.ua: 'Чому стрічка не відображається у списку сканування?',
        },
        'a': {
          AppLanguage.en: 'iOS hides already connected BLE devices. We have fixed this: connected system devices now show up instantly when you scan! If it still does not appear, ensure Bluetooth is enabled in your phone Settings and you have granted all permissions.',
          AppLanguage.ru: 'iOS скрывает уже подключенные Bluetooth-устройства. Мы исправили это: теперь подключенные к системе устройства отображаются мгновенно при начале сканирования! Если она все равно не видна, убедитесь, что Bluetooth включен в настройках телефона и приложению даны все разрешения.',
          AppLanguage.ua: 'iOS приховує вже підключені Bluetooth-пристрої. Ми виправили це: тепер підключені до системи пристрої відображаються миттєво при початку сканування! Якщо вона все одно не відображається, переконайтеся, що Bluetooth увімкнено в налаштуваннях телефону та додатку надано всі дозволи.',
        }
      },
      {
        'q': {
          AppLanguage.en: 'What devices are supported?',
          AppLanguage.ru: 'Какие типы лент поддерживаются?',
          AppLanguage.ua: 'Які типи стрічок підтримуються?',
        },
        'a': {
          AppLanguage.en: 'OmniLight supports SP110E, ELK-BLEDOM, BLEDOM, LEDBLE, iLinker, QHM-BLS, and other compatible BLE controllers using the custom Driver/Adapter pattern.',
          AppLanguage.ru: 'OmniLight поддерживает контроллеры SP110E, ELK-BLEDOM, BLEDOM, LEDBLE, iLinker, QHM-BLS и другие совместимые BLE-устройства через архитектуру универсальных драйверов.',
          AppLanguage.ua: 'OmniLight підтримує контролери SP110E, ELK-BLEDOM, BLEDOM, LEDBLE, iLinker, QHM-BLS та інші сумісні BLE-пристрої через архітектуру універсальних драйверов.',
        }
      },
      {
        'q': {
          AppLanguage.en: 'Do I need to pair the device in iOS Bluetooth settings?',
          AppLanguage.ru: 'Нужно ли сопрягать ленту в настройках Bluetooth iOS?',
          AppLanguage.ua: 'Чи потрібно зпрягати стрічку в налаштуваннях Bluetooth iOS?',
        },
        'a': {
          AppLanguage.en: 'No, BLE devices connect directly inside the app. Do not pair them in the system settings, as this may lock the device and make it unavailable to the app.',
          AppLanguage.ru: 'Нет, BLE-устройства подключаются напрямую внутри приложения. Не сопрягайте их в системных настройках телефона, так как это может заблокировать устройство для сторонних приложений.',
          AppLanguage.ua: 'Ні, BLE-пристрої підключаються безпосередньо всередині додатку. Не зпрягайте їх у системних налаштуваннях телефону, оскільки це може заблокувати пристрій для інших додатків.',
        }
      },
      {
        'q': {
          AppLanguage.en: 'The app says connected, but the strip is not lighting up?',
          AppLanguage.ru: 'Приложение пишет "Подключено", но лента не горит?',
          AppLanguage.ua: 'Додаток пише "Підключено", але стрічка не світиться?',
        },
        'a': {
          AppLanguage.en: 'Make sure that the controller is powered on (check the physical adapter) and press the "Turn ON" button in the app. Also check if the brightness slider is turned up.',
          AppLanguage.ru: 'Убедитесь, что на контроллер подано питание (горит ли светодиод на самом блоке), и нажмите кнопку "Включить" в приложении. Также проверьте, что слайдер яркости сдвинут вправо.',
          AppLanguage.ua: 'Переконайтеся, що на контролер подано живлення (чи світиться світлодіод на самому блоці), та натисніть кнопку "Увімкнути" в додатку. Також перевірте, чи слайдер яскравості зсунутий вправо.',
        }
      }
    ];

    // Вычисляем высоту под шторку (не более 75% экрана)
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: themeData.hasGlow
            ? [
                BoxShadow(
                  color: themeData.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ]
            : [],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Индикатор перетаскивания
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // Шапка листа поддержки
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    store.tr('support_title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: themeData.themeData.colorScheme.onSurface,
                    ),
                  ),
                  if (manager.connectionHistory.isNotEmpty)
                    TextButton(
                      onPressed: () => manager.clearHistory(),
                      child: Text(
                        clearHistoryText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Ограничиваем контент по высоте и делаем его прокручиваемым
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight - 100),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── РАЗДЕЛ: История подключений ──
                      Text(
                        historyTitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: themeData.accentPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (manager.connectionHistory.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: themeData.themeData.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            emptyHistoryMsg,
                            style: TextStyle(
                              fontSize: 13,
                              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: manager.connectionHistory.length,
                          itemBuilder: (context, index) {
                            final item = manager.connectionHistory[index];
                            final id = item['id']!;
                            final name = item['name']!;
                            
                            // Проверяем текущее активное подключение
                            final isActive = manager.state == DeviceManagerState.connected &&
                                manager.connectedDeviceName == name;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: themeData.themeData.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive
                                      ? themeData.accentPrimary.withValues(alpha: 0.4)
                                      : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                                    color: isActive ? themeData.accentPrimary : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: themeData.themeData.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          id,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Кнопка подключения / статус
                                  if (isActive)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          connectedStatusText,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF34C759),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        backgroundColor: themeData.accentPrimary.withValues(alpha: 0.15),
                                        foregroundColor: themeData.accentPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context); // Закрываем шторку
                                        manager.connectToSavedDevice(id, name);
                                      },
                                      child: Text(
                                        connectBtnText,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  
                                  const SizedBox(width: 8),
                                  // Удалить из истории
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                    onPressed: () => manager.removeFromHistory(id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 24),

                      // ── РАЗДЕЛ: FAQ ──
                      Text(
                        faqTitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: themeData.accentPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ...faqs.map((faq) {
                        return _FaqTile(
                          question: t(faq['q']!),
                          answer: t(faq['a']!),
                          themeData: themeData,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: кастомный анимируемый FAQ-тайл
// ─────────────────────────────────────────────────────────────────────────────
class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  final AppThemeData themeData;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.themeData,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeData = widget.themeData;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: themeData.themeData.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded
              ? themeData.accentPrimary.withValues(alpha: 0.4)
              : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              widget.question,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: themeData.themeData.colorScheme.onSurface,
              ),
            ),
            trailing: Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: themeData.accentPrimary,
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
