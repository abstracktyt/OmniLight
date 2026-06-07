# ============================================================
# OmniLight by Abstrackt
# Файл: deploy.ps1
# Назначение: PowerShell-скрипт автоматизации деплоя.
#             Предпочтительный вариант для современных Windows-систем.
#             Поддерживает кастомные сообщения коммитов, валидацию
#             окружения и цветной вывод статуса выполнения.
#
# Использование:
#   PowerShell: .\deploy.ps1
#   PowerShell: .\deploy.ps1 -Message "Добавлен новый драйвер TRIONES"
#
# При первом запуске возможно требование: Set-ExecutionPolicy RemoteSigned
# ============================================================

param(
    # Опциональное сообщение коммита. Если не задано — генерируется автоматически.
    [string]$Message = ""
)

# ── Настройки вывода ──
$ErrorActionPreference = "Stop"  # Прерывать при любой ошибке PowerShell

# ─────────────────────────────────────────────
# Вспомогательные функции вывода
# ─────────────────────────────────────────────

function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host "   OmniLight by Abstrackt — PowerShell Deploy Script       " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Step {
    param([string]$StepNum, [string]$StepText)
    Write-Host "[$StepNum] $StepText" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Text)
    Write-Host "  [✓] $Text" -ForegroundColor Green
}

function Write-Err {
    param([string]$Text)
    Write-Host "  [✗] $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [i] $Text" -ForegroundColor Gray
}

# ─────────────────────────────────────────────
# Функция: Выполнить git-команду с обработкой ошибок
# ─────────────────────────────────────────────
function Invoke-Git {
    param([string[]]$Args)

    # Запускаем git и перехватываем stdout + stderr
    $output = & git @Args 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Err "git $($Args -join ' ') завершился с кодом $exitCode"
        Write-Host $output -ForegroundColor DarkRed
        throw "Ошибка git: $($Args -join ' ')"
    }

    return $output
}

# ─────────────────────────────────────────────
# Функция: Проверить наличие git в PATH
# ─────────────────────────────────────────────
function Assert-GitInstalled {
    try {
        & git --version | Out-Null
    } catch {
        Write-Err "git не найден. Установите Git: https://git-scm.com"
        exit 1
    }
}

# ─────────────────────────────────────────────
# ОСНОВНАЯ ЛОГИКА СКРИПТА
# ─────────────────────────────────────────────
Write-Header

# ── Проверяем git ──
Assert-GitInstalled
Write-Ok "git доступен в PATH"

# ── Формируем сообщение коммита ──
if ([string]::IsNullOrEmpty($Message)) {
    # Генерируем временную метку: YYYY-MM-DD HH:mm
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $commitMessage = "Auto-deploy: Update OmniLight by Abstrackt [$timestamp]"
} else {
    $commitMessage = $Message
}

Write-Info "Сообщение коммита: $commitMessage"
Write-Host ""

# ─────────────────────────────────────────────
# Шаг 1: Проверяем наличие Git-репозитория
# ─────────────────────────────────────────────
Write-Step "1/4" "Проверяем Git-репозиторий..."
try {
    Invoke-Git @("status") | Out-Null
    Write-Ok "Репозиторий найден"
} catch {
    Write-Err "Текущая папка не является Git-репозиторием"
    Write-Info "Инициализируйте репозиторий: git init && git remote add origin <URL>"
    exit 1
}

# ─────────────────────────────────────────────
# Шаг 2: Добавляем все изменения
# ─────────────────────────────────────────────
Write-Step "2/4" "Индексируем изменения (git add .)..."
Invoke-Git @("add", ".") | Out-Null
Write-Ok "Все изменения добавлены в индекс"

# ─────────────────────────────────────────────
# Проверяем — есть ли что коммитить
# ─────────────────────────────────────────────
$diffResult = & git diff --cached --quiet
$nothingToCommit = ($LASTEXITCODE -eq 0)

if ($nothingToCommit) {
    Write-Host ""
    Write-Info "Нет изменений для коммита. Рабочее дерево чистое."
    Write-Info "Push не требуется. Скрипт завершён."
    Write-Host ""
    exit 0
}

# ─────────────────────────────────────────────
# Шаг 3: Создаём коммит
# ─────────────────────────────────────────────
Write-Step "3/4" "Создаём коммит..."
Invoke-Git @("commit", "-m", $commitMessage) | Out-Null
Write-Ok "Коммит создан: $commitMessage"

# ─────────────────────────────────────────────
# Шаг 4: Пушим на GitHub
# ─────────────────────────────────────────────
Write-Step "4/4" "Отправляем на GitHub (git push origin main)..."
$pushOutput = Invoke-Git @("push", "origin", "main")
Write-Ok "Push выполнен успешно"

if ($pushOutput) {
    Write-Host ""
    $pushOutput | ForEach-Object { Write-Info $_ }
}

# ─────────────────────────────────────────────
# Финальный отчёт
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "   [УСПЕХ] OmniLight успешно задеплоен!                    " -ForegroundColor Green
Write-Host "   GitHub Actions CI запущен автоматически.                " -ForegroundColor Gray
Write-Host "   Статус: https://github.com/[ваш-логин]/OmniLight/actions" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""
