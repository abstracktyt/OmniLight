# OmniLight by Abstrackt

> Универсальный Bluetooth-контроллер LED-лент для iOS.  
> Flutter • BLE • Multi-Protocol • Multi-Theme • Multi-Language

---

## Структура проекта

```
OmniLight/
├── lib/
│   ├── main.dart                          # Точка входа, инициализация провайдеров
│   ├── core/
│   │   ├── localization_theme_store.dart  # Управление языком (EN/RU/UA) и темой
│   │   └── device_manager.dart            # BLE-менеджер: скан, подключение, маршрутизация
│   ├── drivers/
│   │   └── led_driver.dart                # BaseLedDriver + Sp110eDriver + ElkBledomDriver
│   └── screens/
│       └── main_screen.dart               # Полный UI главного экрана
├── .github/
│   └── workflows/
│       └── ios-build.yml                  # GitHub Actions CI/CD
├── ios_info_plist_additions.xml           # BLE-разрешения для Info.plist
├── deploy.bat                             # Windows: деплой одним кликом
├── deploy.ps1                             # PowerShell: расширенный деплой
├── pubspec.yaml                           # Зависимости Flutter
├── analysis_options.yaml                  # Конфигурация линтера
└── .gitignore
```

## Добавление нового LED-протокола

1. В `lib/drivers/led_driver.dart` создайте новый класс-наследник `_BaseDriverImpl`
2. Реализуйте все абстрактные методы: `setRgb`, `setBrightness`, `turnOn`, `turnOff`
3. Укажите `serviceConfig` (UUID сервиса и характеристики)
4. Задайте `deviceNamePatterns` — имена BLE-устройств этого протокола
5. В `lib/core/device_manager.dart` добавьте экземпляр в список `_availableDrivers`

## iOS Info.plist

Скопируйте содержимое `ios_info_plist_additions.xml` в `ios/Runner/Info.plist`.

## CI/CD

- Push в `main` → автоматически запускает GitHub Actions сборку
- Артефакт `.zip` доступен для скачивания 30 дней во вкладке Actions
- `deploy.bat` / `deploy.ps1` — локальная автоматизация git add → commit → push
