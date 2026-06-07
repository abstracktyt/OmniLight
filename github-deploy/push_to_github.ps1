param()
# Примечание: не устанавливаем ErrorActionPreference=Stop, так как git возвращает ненулевые коды на многие штатные операции
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   OmniLight - Загрузка проекта на GitHub" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Проверяем наличие git
try {
    $gitVer = & git --version 2>&1
    Write-Host "  Найден Git: $gitVer" -ForegroundColor DarkGray
} catch {
    Write-Host "  ОШИБКА: Git не найден на вашем компьютере!" -ForegroundColor Red
    Write-Host "  Скачайте и установите его с: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# Запрашиваем имя пользователя на GitHub
Write-Host ""
Write-Host "  Введите ваше имя пользователя (логин) на GitHub:" -ForegroundColor White
$GithubUser = Read-Host "  Логин"
if (-not $GithubUser) {
    Write-Host "  ОШИБКА: Логин не может быть пустым" -ForegroundColor Red
    exit 1
}

# Запрашиваем имя репозитория
Write-Host ""
Write-Host "  Имя репозитория (нажмите Enter для значения по умолчанию: OmniLight):" -ForegroundColor White
$RepoName = Read-Host "  Имя репозитория"
if (-not $RepoName) { $RepoName = "OmniLight" }

$RepoURL = "https://github.com/" + $GithubUser + "/" + $RepoName + ".git"
Write-Host ""
Write-Host "  Код будет отправлен в: $RepoURL" -ForegroundColor DarkGray

# Инструкции по созданию репозитория
Write-Host ""
Write-Host "  ШАГ 1: Создайте репозиторий на GitHub" -ForegroundColor Yellow
Write-Host "  ------------------------------------"
Write-Host "  1. Откройте в браузере: https://github.com/new" -ForegroundColor Cyan
Write-Host "  2. Укажите имя репозитория: $RepoName" -ForegroundColor Cyan
Write-Host "  3. Видимость: Public (это бесплатно и дает безлимитные минуты сборки)" -ForegroundColor Cyan
Write-Host "  4. Нажмите кнопку 'Create repository'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Нажмите ENTER, когда создадите репозиторий на сайте..." -ForegroundColor Yellow
$null = Read-Host

# Инициализируем Git
Set-Location $RepoRoot
Write-Host ""
Write-Host "  [1/5] Инициализация Git..." -ForegroundColor Yellow
if (-not (Test-Path ".git")) {
    & git init
} else {
    Write-Host "  Git уже инициализирован" -ForegroundColor DarkGray
}
Write-Host "  Успешно" -ForegroundColor Green

# Индексируем файлы
Write-Host ""
Write-Host "  [2/5] Добавление файлов в индекс..." -ForegroundColor Yellow
& git add .
Write-Host "  Успешно" -ForegroundColor Green

# Создаем первый коммит
Write-Host ""
Write-Host "  [3/5] Создание коммита..." -ForegroundColor Yellow
$commitMsg = "Initial commit: OmniLight Universal LED Controller by Abstrackt v1.0"
& git config user.email "omnilight-user@noreply.github.com" 2>$null
& git config user.name "OmniLight User" 2>$null
$commitOut = & git commit -m $commitMsg 2>&1
if ($LASTEXITCODE -ne 0) {
    $outStr = $commitOut | Out-String
    if ($outStr -notmatch "nothing to commit") {
        Write-Host "  Вывод коммита: $outStr" -ForegroundColor DarkGray
    } else {
        Write-Host "  Нет новых изменений для коммита (ОК)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  Успешно" -ForegroundColor Green
}

# Подключаем удаленный репозиторий
Write-Host ""
Write-Host "  [4/5] Подключение к GitHub..." -ForegroundColor Yellow
$existingRemotes = & git remote 2>&1
if ($existingRemotes -contains "origin") {
    & git remote remove origin 2>&1 | Out-Null
}
& git remote add origin $RepoURL
& git branch -M main
Write-Host "  Успешно" -ForegroundColor Green

# Инструкция по созданию токена доступа
Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  ШАГ 2: Получите токен доступа (Personal Access Token)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  GitHub больше не принимает обычные пароли для авторизации через консоль." -ForegroundColor White
Write-Host "  Вместо пароля вам нужно будет ввести Токен доступа." -ForegroundColor White
Write-Host ""
Write-Host "  Как его получить:" -ForegroundColor White
Write-Host "  1. Перейдите по ссылке: https://github.com/settings/tokens/new" -ForegroundColor Cyan
Write-Host "  2. В поле 'Note' напишите: OmniLight Deploy" -ForegroundColor Cyan
Write-Host "  3. Выберите срок действия (Expiration), например: 'No expiration' (без истечения) или 30 дней" -ForegroundColor Cyan
Write-Host "  4. В списке прав (Scopes) поставьте галочку рядом с самым верхним пунктом: [x] repo" -ForegroundColor Cyan
Write-Host "  5. Прокрутите вниз и нажмите кнопку 'Generate token'" -ForegroundColor Cyan
Write-Host "  6. ОБЯЗАТЕЛЬНО скопируйте созданный токен (он показывается только один раз!)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Когда git запросит пароль (Password) в консоли -> вставьте скопированный токен." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Нажмите ENTER для начала отправки кода..." -ForegroundColor Yellow
$null = Read-Host

# Отправляем на GitHub
Write-Host ""
Write-Host "  [5/5] Отправка кода на GitHub..." -ForegroundColor Yellow
Write-Host "  При появлении запроса введите имя пользователя и вставьте ТОКЕН вместо пароля" -ForegroundColor DarkGray
Write-Host ""
& git push -u origin main

$pushSuccess = ($LASTEXITCODE -eq 0)

if (-not $pushSuccess) {
    Write-Host ""
    Write-Host "  Отправка отклонена или не удалась. Это обычно происходит, если в репозитории на GitHub уже есть файлы (например, README или .gitignore)." -ForegroundColor Yellow
    Write-Host "  Хотите выполнить FORCE PUSH (перезаписать файлы на GitHub вашими локальными)? (y/n):" -ForegroundColor White
    $forceChoice = Read-Host "  Выбор"
    if ($forceChoice -eq "y") {
        Write-Host ""
        Write-Host "  Принудительная отправка (force push)..." -ForegroundColor Yellow
        & git push -f -u origin main
        $pushSuccess = ($LASTEXITCODE -eq 0)
    }
}

if ($pushSuccess) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  УСПЕХ! Ваш код успешно загружен на GitHub!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Следующие шаги:" -ForegroundColor White
    Write-Host "  1. Откройте в браузере ваш репозиторий: https://github.com/$GithubUser/$RepoName" -ForegroundColor Cyan
    Write-Host "  2. Перейдите на вкладку 'Actions'" -ForegroundColor Cyan
    Write-Host "  3. Выберите воркфлоу 'Build OmniLight iOS'" -ForegroundColor Cyan
    Write-Host "  4. Нажмите 'Run workflow' -> 'Run workflow'" -ForegroundColor Cyan
    Write-Host "  5. Подождите 10-15 минут, пока соберется проект" -ForegroundColor Cyan
    Write-Host "  6. Скачайте архив сборки внизу страницы в разделе 'Artifacts'" -ForegroundColor Cyan
    Write-Host "  7. Установите полученный .ipa на iPhone через Sideloadly" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Открыть страницу GitHub Actions в браузере прямо сейчас? (y/n):" -ForegroundColor White
    $openBrowser = Read-Host "  Выбор"
    if ($openBrowser -eq "y") {
        Start-Process ("https://github.com/" + $GithubUser + "/" + $RepoName + "/actions")
    }
} else {
    Write-Host ""
    Write-Host "  ОШИБКА: Не удалось отправить код!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Проверьте:" -ForegroundColor Yellow
    Write-Host "  - Что репозиторий действительно создан: https://github.com/$GithubUser/$RepoName" -ForegroundColor Yellow
    Write-Host "  - Что у вашего токена доступа включена галочка 'repo'" -ForegroundColor Yellow
    Write-Host "  - Что вы правильно ввели логин" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Вы можете попробовать выполнить отправку вручную в консоли:" -ForegroundColor White
    Write-Host "  cd d:\OmniLight" -ForegroundColor DarkGray
    Write-Host "  git push -u origin main" -ForegroundColor DarkGray
    exit 1
}

