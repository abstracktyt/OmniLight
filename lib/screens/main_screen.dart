// ============================================================
// OmniLight by Abstrackt
// Файл: main_screen.dart
// Назначение: Главный экран приложения.
//             Реализует премиальный многостраничный интерфейс (4 вкладки):
//               1. Управление (Control) - пикер, яркость, пресеты, избранные цвета
//               2. Эффекты (Effects) - сетка 16 эффектов, скорость, светомузыка
//               3. Группы (Groups) - управление несколькими лентами одновременно
//               4. Поддержка (Support) - история, FAQ, обратная связь по почте
//             Поддерживает Glassmorphism, неоновые градиенты и тактильный отклик.
// ============================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
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
  final String labelKey;
  final Color color;

  const _ColorPreset({
    required this.labelKey,
    required this.color,
  });
}

const List<_ColorPreset> _presets = [
  _ColorPreset(labelKey: 'preset_red', color: Color(0xFFFF2D55)),
  _ColorPreset(labelKey: 'preset_green', color: Color(0xFF34C759)),
  _ColorPreset(labelKey: 'preset_blue', color: Color(0xFF007AFF)),
  _ColorPreset(labelKey: 'preset_white', color: Color(0xFFFFFFFF)),
  _ColorPreset(labelKey: 'preset_warm', color: Color(0xFFFF9F0A)),
];

// ─────────────────────────────────────────────────────────────────────────────
// Виджет: MainScreen
// ─────────────────────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  double _effectSpeed = 50.0;
  Color _pickerColor = const Color(0xFF007AFF);
  Timer? _colorDebounceTimer;

  // ── Светомузыка (Music Sync) ──
  bool _isMusicSyncing = false;
  Timer? _musicSyncTimer;
  Timer? _eqAnimationTimer;
  final List<double> _equalizerHeights = List.filled(12, 6.0);
  final Random _random = Random();

  // ── Анимации статус-индикаторов ──
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _scanRingController;
  late final Animation<double> _scanRingAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _musicSyncTimer?.cancel();
    _eqAnimationTimer?.cancel();
    _pulseController.dispose();
    _scanRingController.dispose();
    super.dispose();
  }

  // ── Тактильный отклик ──
  void _hapticMedium() => HapticFeedback.mediumImpact();
  void _hapticLight() => HapticFeedback.lightImpact();

  // ── Обработчик изменения цвета с Debounce 50ms ──
  void _onColorChanged(Color color) {
    setState(() => _pickerColor = color);
    _colorDebounceTimer?.cancel();
    _colorDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      final manager = context.read<DeviceManager>();
      if (manager.activeDrivers.isNotEmpty) {
        manager.setRgb(
          (color.r * 255.0).round().clamp(0, 255),
          (color.g * 255.0).round().clamp(0, 255),
          (color.b * 255.0).round().clamp(0, 255),
        );
      }
    });
  }

  // ── Применить пресет цвета ──
  Future<void> _applyPreset(Color color) async {
    _hapticLight();
    setState(() => _pickerColor = color);
    final manager = context.read<DeviceManager>();
    if (manager.activeDrivers.isNotEmpty) {
      await manager.setRgb(
        (color.r * 255.0).round().clamp(0, 255),
        (color.g * 255.0).round().clamp(0, 255),
        (color.b * 255.0).round().clamp(0, 255),
      );
    }
  }

  // ── Управление Светомузыкой ──
  void _toggleMusicSync() {
    _hapticMedium();
    final manager = context.read<DeviceManager>();

    if (_isMusicSyncing) {
      _musicSyncTimer?.cancel();
      _eqAnimationTimer?.cancel();
      setState(() {
        _isMusicSyncing = false;
        for (int i = 0; i < _equalizerHeights.length; i++) {
          _equalizerHeights[i] = 6.0;
        }
      });
      // Восстанавливаем исходный выбранный цвет
      if (manager.activeDrivers.isNotEmpty) {
        manager.setRgb(
          (_pickerColor.r * 255.0).round().clamp(0, 255),
          (_pickerColor.g * 255.0).round().clamp(0, 255),
          (_pickerColor.b * 255.0).round().clamp(0, 255),
        );
      }
    } else {
      if (manager.activeDrivers.isEmpty) return;
      setState(() => _isMusicSyncing = true);

      // Анимация прыгающего эквалайзера
      _eqAnimationTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
        setState(() {
          for (int i = 0; i < _equalizerHeights.length; i++) {
            _equalizerHeights[i] = _random.nextDouble() * 32.0 + 4.0;
          }
        });
      });

      // Передача импульсов на ленту
      _musicSyncTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        final r = _random.nextInt(256);
        final g = _random.nextInt(256);
        final b = _random.nextInt(256);
        // Добавляем яркости цветам
        final maxVal = max(r, max(g, b));
        if (maxVal < 100) {
          manager.setRgb(r + 100, g + 100, b + 100);
        } else {
          manager.setRgb(r, g, b);
        }
      });
    }
  }

  // ── Модалка настроек ──
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
  // BUILD: Основная структура со вкладками
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalizationThemeStore>();
    final manager = context.watch<DeviceManager>();
    final themeData = store.currentThemeData;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(store, themeData),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  _buildControlTab(store, manager, themeData),
                  _buildEffectsTab(store, manager, themeData),
                  _buildGroupTab(store, manager, themeData),
                  _buildSupportTab(store, manager, themeData),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(store, themeData),
    );
  }

  // ─────────────────────────────────────────────
  // Виджет: Шапка приложения
  // ─────────────────────────────────────────────
  Widget _buildHeader(LocalizationThemeStore store, AppThemeData themeData) {
    final isCyber = store.appTheme == AppTheme.cyberNeon;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeData.accentPrimary, themeData.accentSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isCyber
                  ? [
                      BoxShadow(
                        color: themeData.glowColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.lightbulb_rounded,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.tr('app_title'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: themeData.themeData.colorScheme.onSurface,
                    letterSpacing: -0.5,
                    shadows: isCyber
                        ? [Shadow(color: themeData.accentPrimary.withValues(alpha: 0.7), blurRadius: 10)]
                        : null,
                  ),
                ),
                Text(
                  store.tr('app_subtitle'),
                  style: TextStyle(
                    fontSize: 11,
                    color: themeData.accentPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
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
  // Виджет: Bottom Navigation Bar (Glassmorphism)
  // ─────────────────────────────────────────────
  Widget _buildBottomBar(LocalizationThemeStore store, AppThemeData themeData) {
    final isCyber = store.appTheme == AppTheme.cyberNeon;
    final items = [
      {'icon': Icons.palette_outlined, 'activeIcon': Icons.palette_rounded, 'label': 'tab_control'},
      {'icon': Icons.auto_awesome_outlined, 'activeIcon': Icons.auto_awesome_rounded, 'label': 'tab_effects'},
      {'icon': Icons.layers_outlined, 'activeIcon': Icons.layers_rounded, 'label': 'tab_group'},
      {'icon': Icons.help_outline_rounded, 'activeIcon': Icons.help_rounded, 'label': 'tab_support'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: themeData.cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeData.accentPrimary.withValues(alpha: isCyber ? 0.4 : 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (isCyber)
            BoxShadow(
              color: themeData.accentPrimary.withValues(alpha: 0.15),
              blurRadius: 15,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = _currentTab == index;
                final item = items[index];
                final activeColor = themeData.accentPrimary;

                return GestureDetector(
                  onTap: () {
                    _hapticLight();
                    setState(() => _currentTab = index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? (item['activeIcon'] as IconData) : (item['icon'] as IconData),
                          color: isSelected ? activeColor : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          store.tr(item['label'] as String),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? activeColor : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // ВКЛАДКА 1: Управление (Control Tab)
  // ═════════════════════════════════════════════
  Widget _buildControlTab(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isConnected = manager.activeDrivers.isNotEmpty;
    final isScanning = manager.isScanning;

    return SingleChildScrollView(
      physics: kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Статус-бар подключения
          _buildStatusBarWidget(store, manager, themeData),
          const SizedBox(height: 12),

          // Список найденных при сканировании устройств
          if (isScanning || manager.discoveredDevices.isNotEmpty) ...[
            _buildScanListWidget(store, manager, themeData),
            const SizedBox(height: 12),
          ],

          // Кнопки сканирования
          _buildScanControlsWidget(store, manager, themeData),
          const SizedBox(height: 16),

          // Пикер цвета (под замком, если не подключено)
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: _buildPickerCardWidget(store, themeData),
            ),
          ),
          const SizedBox(height: 12),

          // Яркость
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: _buildBrightnessSliderWidget(store, manager, themeData),
            ),
          ),
          const SizedBox(height: 12),

          // Быстрые пресеты и питание
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: Column(
                children: [
                  _buildPresetsWidget(store, themeData),
                  const SizedBox(height: 16),
                  _buildPowerControlsWidget(store, manager, themeData),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Статус-бар виджет
  Widget _buildStatusBarWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isConnected = manager.activeDrivers.isNotEmpty;
    final isScanning = manager.isScanning;

    Color statusColor = const Color(0xFF8E8E93);
    String statusText = store.tr('status_disconnected');

    if (isConnected) {
      statusColor = const Color(0xFF34C759);
      statusText = '${store.tr("status_connected")} ${manager.connectedDeviceName ?? ""}';
    } else if (manager.isConnecting) {
      statusColor = themeData.accentPrimary;
      statusText = store.tr('status_connecting');
    } else if (isScanning) {
      statusColor = themeData.accentPrimary;
      statusText = store.tr('status_scanning');
    } else if (manager.state == DeviceManagerState.bleOff) {
      statusColor = const Color(0xFFFF3B30);
      statusText = store.tr('ble_off');
    } else if (manager.state == DeviceManagerState.permissionDenied) {
      statusColor = const Color(0xFFFF3B30);
      statusText = store.tr('ble_permission_denied');
    } else if (manager.state == DeviceManagerState.error) {
      statusColor = const Color(0xFFFF3B30);
      statusText = manager.errorMessage ?? store.tr('status_error');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: themeData.hasGlow
            ? [BoxShadow(color: statusColor.withValues(alpha: 0.15), blurRadius: 10)]
            : [],
      ),
      child: Row(
        children: [
          if (isScanning || manager.isConnecting)
            SizedBox(
              width: 14,
              height: 14,
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
                opacity: isConnected ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: themeData.themeData.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isConnected && manager.activeDriver != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: themeData.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                manager.activeDriver!.driverName,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: themeData.accentPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Список сканирования
  Widget _buildScanListWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final unconnectDevices = manager.discoveredDevices.where((discovered) {
      final id = discovered.device.remoteId.toString();
      return !manager.activeDrivers.containsKey(id);
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeData.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              store.tr('select_device').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: themeData.accentPrimary,
                letterSpacing: 1.0,
              ),
            ),
          ),
          if (unconnectDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  store.tr('no_devices_found'),
                  style: TextStyle(
                    fontSize: 12,
                    color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            )
          else
            ...unconnectDevices.map((d) {
              return _DeviceTile(
                discovered: d,
                themeData: themeData,
                onTap: () {
                  _hapticMedium();
                  manager.connectToDevice(d);
                },
              );
            }),
        ],
      ),
    );
  }

  // Кнопки сканирования
  Widget _buildScanControlsWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isScanning = manager.isScanning;
    final isConnected = manager.activeDrivers.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _NeonButton(
            label: isScanning ? store.tr('btn_disconnect') : store.tr('btn_scan'),
            icon: isScanning ? Icons.stop_rounded : Icons.bluetooth_searching_rounded,
            themeData: themeData,
            isLoading: manager.isConnecting,
            enabled: !manager.isConnecting,
            isPrimary: true,
            onTap: () {
              _hapticLight();
              if (isScanning) {
                manager.stopScan();
              } else {
                manager.startScan();
              }
            },
          ),
        ),
        if (isConnected) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _NeonButton(
              label: store.tr('btn_disconnect'),
              icon: Icons.bluetooth_disabled_rounded,
              themeData: themeData,
              isLoading: false,
              enabled: true,
              isPrimary: false,
              onTap: () {
                _hapticMedium();
                manager.disconnectCurrent();
              },
            ),
          ),
        ],
      ],
    );
  }

  // Пикер цвета с кастомными пресетами (избранным)
  Widget _buildPickerCardWidget(LocalizationThemeStore store, AppThemeData themeData) {
    return Container(
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: themeData.hasGlow
            ? [BoxShadow(color: _pickerColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 1)]
            : [],
      ),
      child: Column(
        children: [
          // Заголовок и кнопка добавить в избранное
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.palette_rounded, color: themeData.accentPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  store.tr('color_picker_label'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: themeData.themeData.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Кнопка сохранения цвета
                IconButton(
                  icon: const Icon(Icons.favorite_rounded),
                  color: store.favoriteColors.any((c) => c.toARGB32() == _pickerColor.toARGB32())
                      ? Colors.redAccent
                      : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.35),
                  iconSize: 22,
                  onPressed: () {
                    _hapticLight();
                    if (store.favoriteColors.any((c) => c.toARGB32() == _pickerColor.toARGB32())) {
                      store.removeFavoriteColor(_pickerColor);
                    } else {
                      store.addFavoriteColor(_pickerColor);
                    }
                  },
                ),
                // Превью цвета
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _pickerColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _pickerColor.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Цветовое колесо
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: SizedBox(
                width: 280,
                child: ColorPicker(
                  pickerColor: _pickerColor,
                  onColorChanged: _onColorChanged,
                  colorPickerWidth: 280,
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsv,
                  labelTypes: const [],
                  pickerAreaBorderRadius: BorderRadius.circular(16),
                  portraitOnly: true,
                ),
              ),
            ),
          ),

          // Избранные цвета
          _buildFavoriteColorsWidget(store, themeData),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // Горизонтальный список избранных цветов
  Widget _buildFavoriteColorsWidget(LocalizationThemeStore store, AppThemeData themeData) {
    final favs = store.favoriteColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                store.tr('favorites_title'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (favs.isNotEmpty)
                Text(
                  store.language == AppLanguage.en
                      ? 'Hold to remove'
                      : (store.language == AppLanguage.ru ? 'Зажмите для удаления' : 'Затисніть для видалення'),
                  style: TextStyle(
                    fontSize: 9,
                    color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (favs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                store.tr('favorites_empty'),
                style: TextStyle(
                  fontSize: 11,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: favs.length,
                itemBuilder: (context, index) {
                  final color = favs[index];
                  final isSelected = _pickerColor.toARGB32() == color.toARGB32();

                  return GestureDetector(
                    onTap: () => _applyPreset(color),
                    onLongPress: () {
                      _hapticMedium();
                      store.removeFavoriteColor(color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? themeData.accentPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: isSelected ? 0.6 : 0.25),
                            blurRadius: isSelected ? 8 : 4,
                            spreadRadius: isSelected ? 1 : 0,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Виджет: Слайдер яркости
  Widget _buildBrightnessSliderWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    return Container(
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
              Icon(Icons.brightness_6_rounded, color: themeData.accentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                store.tr('brightness_label'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${(manager.brightness / 255 * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: themeData.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: themeData.accentPrimary,
              inactiveTrackColor: themeData.accentPrimary.withValues(alpha: 0.15),
              thumbColor: themeData.accentPrimary,
              overlayColor: themeData.accentPrimary.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackHeight: 3.5,
            ),
            child: Slider(
              value: manager.brightness.toDouble(),
              min: 0,
              max: 255,
              onChanged: (val) {
                _hapticLight();
                manager.setBrightness(val.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  // Виджет: Быстрые пресеты
  Widget _buildPresetsWidget(LocalizationThemeStore store, AppThemeData themeData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            store.language == AppLanguage.en
                ? 'Quick Presets'
                : (store.language == AppLanguage.ru ? 'Быстрые цвета' : 'Швидкі кольори'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        Row(
          children: _presets.map((preset) {
            final isSelected = _pickerColor.toARGB32() == preset.color.toARGB32();
            return Expanded(
              child: GestureDetector(
                onTap: () => _applyPreset(preset.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.color.withValues(alpha: 0.15)
                        : themeData.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? preset.color : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: preset.color.withValues(alpha: 0.2), blurRadius: 8)]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: preset.color.withValues(alpha: 0.35), blurRadius: 4)
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        store.tr(preset.labelKey),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: themeData.themeData.colorScheme.onSurface.withValues(alpha: isSelected ? 0.9 : 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Виджет: Питание
  Widget _buildPowerControlsWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    return Row(
      children: [
        Expanded(
          child: _NeonButton(
            label: store.tr('btn_turn_on'),
            icon: Icons.power_settings_new_rounded,
            themeData: themeData,
            isLoading: false,
            enabled: true,
            isPrimary: true,
            onTap: () {
              _hapticMedium();
              manager.turnOn();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _NeonButton(
            label: store.tr('btn_turn_off'),
            icon: Icons.power_off_rounded,
            themeData: themeData,
            isLoading: false,
            enabled: true,
            isPrimary: false,
            onTap: () {
              _hapticMedium();
              manager.turnOff();
            },
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // ВКЛАДКА 2: Эффекты (Effects Tab)
  // ═════════════════════════════════════════════
  Widget _buildEffectsTab(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isConnected = manager.activeDrivers.isNotEmpty;

    return SingleChildScrollView(
      physics: kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Светомузыка
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: _buildMusicSyncWidget(store, themeData),
            ),
          ),
          const SizedBox(height: 16),

          // Скорость
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: _buildEffectSpeedWidget(store, themeData),
            ),
          ),
          const SizedBox(height: 16),

          // Сетка эффектов
          Opacity(
            opacity: isConnected ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !isConnected,
              child: _buildEffectsGridWidget(store, manager, themeData),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Виджет: Светомузыка (Music Sync Card)
  Widget _buildMusicSyncWidget(LocalizationThemeStore store, AppThemeData themeData) {
    final isCyber = themeData.hasGlow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isMusicSyncing
              ? themeData.accentPrimary
              : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: _isMusicSyncing && isCyber
            ? [BoxShadow(color: themeData.accentPrimary.withValues(alpha: 0.3), blurRadius: 16)]
            : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: _isMusicSyncing ? themeData.accentPrimary : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.tr('music_sync_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: themeData.themeData.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.tr('music_sync_desc'),
                      style: TextStyle(
                        fontSize: 10,
                        color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Визуализатор эквалайзера
          Container(
            height: 48,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_equalizerHeights.length, (idx) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  width: 6,
                  height: _equalizerHeights[idx],
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeData.accentPrimary,
                        themeData.accentSecondary,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Кнопка запуска
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(_isMusicSyncing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_isMusicSyncing ? store.tr('btn_stop') : store.tr('btn_start')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMusicSyncing ? Colors.redAccent : themeData.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _toggleMusicSync,
            ),
          ),
        ],
      ),
    );
  }

  // Виджет: Слайдер скорости эффектов
  Widget _buildEffectSpeedWidget(LocalizationThemeStore store, AppThemeData themeData) {
    return Container(
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
              Icon(Icons.speed_rounded, color: themeData.accentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                store.tr('effect_speed'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_effectSpeed.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: themeData.accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: themeData.accentPrimary,
              inactiveTrackColor: themeData.accentPrimary.withValues(alpha: 0.15),
              thumbColor: themeData.accentPrimary,
              overlayColor: themeData.accentPrimary.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackHeight: 3.5,
            ),
            child: Slider(
              value: _effectSpeed,
              min: 1,
              max: 100,
              onChanged: (val) {
                setState(() => _effectSpeed = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Виджет: Сетка эффектов
  Widget _buildEffectsGridWidget(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final langCode = store.language == AppLanguage.en
        ? 'en'
        : (store.language == AppLanguage.ru ? 'ru' : 'ua');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            store.tr('tab_effects').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 1.0,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: appEffects.length,
          itemBuilder: (context, index) {
            final effect = appEffects[index];
            final name = effect.names[langCode] ?? effect.names['en']!;

            return GestureDetector(
              onTap: () {
                _hapticLight();
                if (_isMusicSyncing) _toggleMusicSync(); // Выключаем светомузыку, если включена
                manager.setEffect(effect.id, _effectSpeed.round());
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: effect.previewColors.length > 1
                        ? effect.previewColors
                        : [effect.previewColors.first, effect.previewColors.first.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: effect.previewColors.first.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Стекло поверх градиента для сглаживания и стиля
                      Container(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // ВКЛАДКА 3: Группы (Groups Tab)
  // ═════════════════════════════════════════════
  Widget _buildGroupTab(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final isScanning = manager.isScanning;
    final connected = manager.connectedStrips;

    return SingleChildScrollView(
      physics: kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Описание группового управления
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeData.accentPrimary.withValues(alpha: 0.15),
                  themeData.accentSecondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: themeData.accentPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers_rounded, color: themeData.accentPrimary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.tr('groups_title'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: themeData.themeData.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        store.tr('groups_broadcast_desc'),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.6),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Список подключенных лент
          Text(
            store.tr('groups_connected_devices').toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          if (connected.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeData.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                store.language == AppLanguage.en
                    ? 'No connected devices yet.'
                    : (store.language == AppLanguage.ru ? 'Нет подключенных устройств.' : 'Немає підключених пристроїв.'),
                style: TextStyle(
                  fontSize: 12,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            )
          else
            ...connected.map((discovered) {
              final id = discovered.device.remoteId.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: themeData.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeData.accentPrimary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: themeData.accentPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.bluetooth_connected_rounded, color: themeData.accentPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            discovered.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: themeData.themeData.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            discovered.matchedDriver?.driverName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: themeData.accentPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
                      onPressed: () {
                        _hapticMedium();
                        manager.disconnectDevice(id);
                      },
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),

          // Поиск новых лент
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (store.language == AppLanguage.en
                        ? 'Search for nearby devices'
                        : (store.language == AppLanguage.ru ? 'Поиск новых устройств' : 'Пошук нових пристроїв'))
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 1.0,
                ),
              ),
              if (isScanning)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.grey)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          _buildScanListWidget(store, manager, themeData),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isScanning ? Icons.stop_rounded : Icons.search_rounded),
              label: Text(
                isScanning
                    ? (store.language == AppLanguage.en
                        ? 'Stop Scan'
                        : (store.language == AppLanguage.ru ? 'Остановить сканирование' : 'Зупинити сканування'))
                    : (store.language == AppLanguage.en
                        ? 'Scan for More'
                        : (store.language == AppLanguage.ru ? 'Искать еще' : 'Шукати ще')),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanning ? Colors.redAccent : themeData.accentPrimary.withValues(alpha: 0.15),
                foregroundColor: isScanning ? Colors.white : themeData.accentPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _hapticLight();
                if (isScanning) {
                  manager.stopScan();
                } else {
                  manager.startScan();
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // ВКЛАДКА 4: Поддержка (Support Tab)
  // ═════════════════════════════════════════════
  Widget _buildSupportTab(
    LocalizationThemeStore store,
    DeviceManager manager,
    AppThemeData themeData,
  ) {
    final lang = store.language;
    String t(Map<AppLanguage, String> map) => map[lang] ?? map[AppLanguage.en]!;

    final emptyHistoryMsg = t({
      AppLanguage.en: 'No saved devices. Connect to a strip on the main screen to save it here.',
      AppLanguage.ru: 'История подключений пуста. Подключитесь к ленте на вкладке Управление, и она сохранится здесь.',
      AppLanguage.ua: 'Історія підключень порожня. Підключіться до стрічки на вкладці Керування, і вона збережеться тут.',
    });

    final faqs = [
      {
        'q': {
          AppLanguage.en: 'Why is my LED strip not showing up in the scan list?',
          AppLanguage.ru: 'Почему лента не отображается в списке сканирования?',
          AppLanguage.ua: 'Чому стрічка не відображається у списку сканування?',
        },
        'a': {
          AppLanguage.en: 'iOS hides already connected BLE devices. We have fixed this: connected system devices now show up instantly when you scan! If it still does not appear, ensure Bluetooth is enabled in phone settings and permissions are granted.',
          AppLanguage.ru: 'iOS скрывает уже подключенные Bluetooth-устройства. Мы исправили это: теперь подключенные к системе устройства отображаются мгновенно при начале сканирования! Если она все равно не видна, убедитесь, что Bluetooth включен в настройках телефона и приложению даны все разрешения.',
          AppLanguage.ua: 'iOS приховує вже підключені Bluetooth-пристрої. Ми виправили це: тепер підключені до системи пристрої відображаються миттєво при початку сканування! Якщо вона все одно не відображається, переконайтеся, що Bluetooth увімкнено в налаштуваннях телефону та додатку надано всі дозволи.',
        }
      },
      {
        'q': {
          AppLanguage.en: 'Can I control multiple strips at once?',
          AppLanguage.ru: 'Можно ли управлять несколькими лентами одновременно?',
          AppLanguage.ua: 'Чи можна керувати кількома стрічками одночасно?',
        },
        'a': {
          AppLanguage.en: 'Yes! Navigate to the "Groups" tab and scan to connect additional strips. Any commands you send will be broadcast to all connected devices concurrently.',
          AppLanguage.ru: 'Да! Перейдите во вкладку "Группы" и запустите сканирование, чтобы подключить новые устройства. Все ваши команды будут одновременно транслироваться на все подключенные ленты.',
          AppLanguage.ua: 'Так! Перейдіть у вкладку "Групи" та запустіть сканування, щоб підключити нові пристрої. Усі ваші команди будуть одночасно транслюватися на всі підключені стрічки.',
        }
      },
      {
        'q': {
          AppLanguage.en: 'Do I need to pair the device in Bluetooth settings?',
          AppLanguage.ru: 'Нужно ли сопрягать ленту в настройках Bluetooth?',
          AppLanguage.ua: 'Чи потрібно зпрягати стрічку в налаштуваннях Bluetooth?',
        },
        'a': {
          AppLanguage.en: 'No, BLE devices connect directly inside the app. Do not pair them in the system settings, as this may lock the device and make it unavailable to the app.',
          AppLanguage.ru: 'Нет, BLE-устройства подключаются напрямую внутри приложения. Не сопрягайте их в системных настройках телефона, так как это может заблокировать устройство для сторонних приложений.',
          AppLanguage.ua: 'Ні, BLE-пристрої підключаються безпосередньо всередині додатку. Не зпрягайте їх у системних налаштуваннях телефону, оскільки це може заблокувати пристрій для інших додатків.',
        }
      },
    ];

    return SingleChildScrollView(
      physics: kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Блок обратной связи
          _buildFeedbackCard(store, themeData),
          const SizedBox(height: 24),

          // История подключений
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t({
                  AppLanguage.en: 'Connection History',
                  AppLanguage.ru: 'История подключений',
                  AppLanguage.ua: 'Історія підключень',
                }).toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 1.0,
                ),
              ),
              if (manager.connectionHistory.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _hapticMedium();
                    manager.clearHistory();
                  },
                  child: Text(
                    t({
                      AppLanguage.en: 'Clear',
                      AppLanguage.ru: 'Очистить',
                      AppLanguage.ua: 'Очистити',
                    }),
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (manager.connectionHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeData.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                emptyHistoryMsg,
                style: TextStyle(
                  fontSize: 11.5,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1.35,
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
                final isActive = manager.activeDrivers.containsKey(id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeData.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? themeData.accentPrimary.withValues(alpha: 0.35) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                        color: isActive ? themeData.accentPrimary : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: themeData.themeData.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              id,
                              style: TextStyle(
                                fontSize: 10,
                                color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.35),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Text(
                          t({
                            AppLanguage.en: 'Active',
                            AppLanguage.ru: 'Активно',
                            AppLanguage.ua: 'Активно',
                          }),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF34C759), fontWeight: FontWeight.w800),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: themeData.accentPrimary.withValues(alpha: 0.15),
                            foregroundColor: themeData.accentPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _hapticMedium();
                            manager.connectToSavedDevice(id, name);
                            setState(() => _currentTab = 0); // Переход на вкладку управления
                          },
                          child: Text(
                            t({
                              AppLanguage.en: 'Connect',
                              AppLanguage.ru: 'Подкл.',
                              AppLanguage.ua: 'Підкл.',
                            }),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _hapticLight();
                          manager.removeFromHistory(id);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // FAQ
          Text(
            t({
              AppLanguage.en: 'Frequently Asked Questions',
              AppLanguage.ru: 'Вопросы и ответы',
              AppLanguage.ua: 'Запитання та відповіді',
            }).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          ...faqs.map((faq) {
            return _FaqTile(
              question: t(faq['q']!),
              answer: t(faq['a']!),
              themeData: themeData,
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Виджет: Карточка обратной связи
  Widget _buildFeedbackCard(LocalizationThemeStore store, AppThemeData themeData) {
    final email = 'abstracktyt@gmail.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeData.accentPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: themeData.accentPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                store.tr('support_feedback_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            store.tr('support_feedback_desc'),
            style: TextStyle(
              fontSize: 11.5,
              color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Строка с адресом почты
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: themeData.themeData.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: themeData.themeData.colorScheme.onSurface,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _hapticLight();
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(store.tr('support_feedback_copied')),
                        duration: const Duration(seconds: 2),
                        backgroundColor: themeData.accentPrimary,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: themeData.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      store.tr('btn_copy'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: themeData.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Строка с Discord-сервером
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: themeData.themeData.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Discord: http://dsc.gg/OmniLight',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5865F2), // Discord color
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _hapticLight();
                    Clipboard.setData(const ClipboardData(text: 'http://dsc.gg/OmniLight'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(store.tr('support_feedback_copied')),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF5865F2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      store.tr('btn_copy'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5865F2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _GlowIconButton
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: themeData.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: themeData.hasGlow
                ? [BoxShadow(color: themeData.accentPrimary.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)]
                : [],
          ),
          child: Icon(icon, size: 20, color: themeData.accentPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: _NeonButton
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
    final accentColor = widget.isPrimary ? widget.themeData.accentPrimary : widget.themeData.accentSecondary;

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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isCyber
              ? (widget.enabled ? accentColor.withValues(alpha: 0.1) : Colors.transparent)
              : (widget.isPrimary
                  ? (widget.enabled ? accentColor : accentColor.withValues(alpha: 0.4))
                  : widget.themeData.cardColor),
          borderRadius: BorderRadius.circular(14),
          border: isCyber
              ? Border.all(color: widget.enabled ? accentColor : accentColor.withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: isCyber && widget.enabled
              ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 10)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accentColor)),
              )
            else
              Icon(
                widget.icon,
                size: 16,
                color: isCyber ? accentColor : (widget.isPrimary ? Colors.white : accentColor),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isCyber ? accentColor : (widget.isPrimary ? Colors.white : accentColor),
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
// Вспомогательный виджет: _DeviceTile
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: themeData.themeData.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSupported
                ? themeData.accentPrimary.withValues(alpha: 0.3)
                : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSupported
                    ? themeData.accentPrimary.withValues(alpha: 0.1)
                    : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bluetooth_rounded,
                color: isSupported ? themeData.accentPrimary : Colors.grey,
                size: 18,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: themeData.themeData.colorScheme.onSurface,
                    ),
                  ),
                  if (isSupported)
                    Text(
                      discovered.matchedDriver!.driverName,
                      style: TextStyle(
                        fontSize: 10,
                        color: themeData.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 14, color: Colors.grey.withValues(alpha: 0.6)),
                Text(
                  '${discovered.rssi}',
                  style: TextStyle(fontSize: 9, color: Colors.grey.withValues(alpha: 0.6)),
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
// Вспомогательный виджет: _SettingsSheet
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
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                store.tr('settings_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Выбор темы
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
              const SizedBox(height: 18),

              // Выбор языка
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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: themeData.accentPrimary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? themeData.accentPrimary.withValues(alpha: 0.15) : themeData.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? themeData.accentPrimary : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? themeData.accentPrimary : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? themeData.accentPrimary : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? themeData.accentPrimary.withValues(alpha: 0.15) : themeData.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? themeData.accentPrimary : Colors.transparent, width: 1.5),
          ),
          child: Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? themeData.accentPrimary : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный виджет: кастомный FAQ-тайл
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: themeData.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded
              ? themeData.accentPrimary.withValues(alpha: 0.35)
              : themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              title: Text(
                widget.question,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: themeData.themeData.colorScheme.onSurface,
                ),
              ),
              trailing: Icon(
                _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: themeData.accentPrimary,
                size: 20,
              ),
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 12,
                  color: themeData.themeData.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}
