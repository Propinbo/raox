# Сборка через Maven

## Windows x64 / Java 21

Нужны Windows x64 и PowerShell 5.1 или 7. Скрипт загружает Temurin **21.0.12.1+1**,
Maven Wrapper — Maven **3.9.11**. Системные установки и PATH не меняются.

```powershell
.\recovery\Initialize-Platform.ps1
.\recovery\Invoke-PlatformBuild.ps1 -Clean
```

По умолчанию выполняется `verify`. Плагины находятся в
`assembly/target/raox-3.9.0.zip`; проверяются 38 JUnit, состав ZIP и SHA-256 зависимостей.
Дополнительная проверка фиксирует 8 000 чисел распределений Commons Math.
Модуль `raox.repository` создаёт локальный p2-репозиторий с зависимостями.

Инструменты находятся в `.build/platform-tools`, выделенный Maven/p2/wrapper-кэш —
в `.build/platform-m2`, логи и JSON — в `.build/platform-evidence`.
Для других каталогов доступны параметры `-ToolchainRoot`, `-CacheRoot`, `-LogRoot`.
`-RequireEmptyCache` отвергает непустой кэш, `-Offline` проверяет повторную сборку
после его заполнения. Сетевые ошибки сохраняются по попыткам; ошибки компиляции
и тестов автоматически не повторяются. `-NetworkRetries 0` отключает повторы.

```powershell
.\recovery\Invoke-PlatformBuild.ps1 -CacheRoot .build/new-m2 -RequireEmptyCache -Clean
.\recovery\Invoke-PlatformBuild.ps1 -CacheRoot .build/new-m2 -Offline -Clean
```

Используйте ASCII-путь исходников; пробелы разрешены. Поддержка Unicode-имён
моделей проверяется отдельно. Установленный дистрибутив проверяется также в пути
с пробелами и кириллицей; ограничение исходников на ASCII остаётся у генератора.

## Самостоятельный дистрибутив Windows x64

Для упаковки и native smoke нужны **PowerShell 7** и **Windows 10 1903+ / 11 x64**.
Сначала выполните сборку выше.

```powershell
.\recovery\Initialize-Platform.ps1 -IncludeUi
.\recovery\New-WindowsDistribution.ps1
$smoke = .\recovery\Invoke-DistributionSmoke.ps1 `
    -ArchivePath assembly/target/windows-x64/raox-3.9.0-windows-x86_64.zip
```

ZIP содержит `raox/eclipse.exe`, Java 21, JDT, Rao X и Game5, лицензии и исходники
LGPL-компонентов. Установка идёт p2 director в пустой каталог исключительно из
`raox.repository/target/repository`; старые Nexus и ручная установка плагинов
не нужны. Загруженный Eclipse используется только как инструмент p2 director.
Для повторной упаковки укажите новый `-OutputRoot`, существующий каталог
приложения скрипт не перезаписывает. Архив p2: `raox.repository/target/*.zip`.

Распакуйте ZIP целиком в доступный для записи каталог, запустите `raox/eclipse.exe`
и выберите новый workspace. JVM указана относительным путём в `eclipse.ini`.
`Invoke-DistributionSmoke.ps1` распаковывает ZIP во временный путь с пробелами и
кириллицей, проверяет хеши файлов и запускает native launcher с удалённым
JAVA_HOME и PATH без Java. Временная копия остаётся для проверки UI.

В копии Windows EXE добавляется per-process UTF-8-манифест для поддержки кириллицы
в пути Java 21; исходная JDK не меняется. `native-launchers.json` фиксирует SHA-256
до и после изменения. Лицензии и ограничения описаны в [THIRD-PARTY.md](recovery/THIRD-PARTY.md).

UI установленного приложения:

```powershell
.\recovery\Invoke-RcpttTests.ps1 `
    -JavaHome (Join-Path $smoke.application jre) `
    -RunnerRoot .build/platform-tools/rcptt `
    -AutRoot $smoke.application `
    -PluginsRoot (Join-Path $smoke.application plugins) `
    -InstalledDistribution -LockRoot recovery/platform -LogRoot .build/distribution-ui
$latestRun = Get-ChildItem .build/distribution-ui -Directory | Sort-Object Name | Select-Object -Last 1
.\recovery\Test-UiExports.ps1 -RunRoot $latestRun.FullName
.\recovery\Test-QuickStartExports.ps1 -RunRoot $latestRun.FullName
```

Библиотеки, координаты, источники, лицензии и ограничения описаны в
[THIRD-PARTY.md](recovery/THIRD-PARTY.md). `Test-EmbeddedLibraries.ps1` проверяет
их фиксированные байты; обычная сборка выполняет эту проверку автоматически.

## Платформа и фиксация зависимостей

Сборка и интерфейс используют Eclipse **2025-09 / 4.37**, Xtext/Xbase/Xtend **2.40.0**,
Guice **7.0.0**, Tycho **4.0.13** и JavaSE-21.
[Target](raox.target/raox.target.target) содержит точные корневые IU и единственный
неизменяемый p2 timestamp-репозиторий. Отдельный Maven-classpath генератора и Xtend
фиксирует EMF и JDT; старый набор fragments заменён на `XtextGenerator / StandardLanguage`.
Грамматика сохранена. Библиотеки обновлены отдельно с проверками совместимости.

[Инструменты и SHA-256](recovery/platform/toolchains.lock.json),
[p2 bundle](recovery/platform/p2-bundles.lock.json),
[Maven-бинарники](recovery/platform/maven-artifacts.lock.csv).
Штатная сборка только проверяет lock-файлы. `Export-PlatformLocks.ps1` предназначен
для осознанного обновления инвентаря после проверки переноса, а не для исправления
несовпадений при обычной сборке. Используйте выделенный кэш без посторонних артефактов.

## Проверки интерфейса

```powershell
.\recovery\Initialize-Platform.ps1 -IncludeUi
.\recovery\Invoke-SwtAwtProbe.ps1
.\recovery\Invoke-RcpttTests.ps1 `
    -JavaHome .build/platform-tools/jdk-21.0.12.1+1 `
    -RunnerRoot .build/platform-tools/rcptt `
    -AutRoot .build/platform-tools/eclipse/eclipse `
    -LockRoot recovery/platform `
    -PluginsRoot assembly/target/plugins -LogRoot .build/ui-evidence
$latestRun = Get-ChildItem .build/ui-evidence -Directory | Sort-Object Name | Select-Object -Last 1
.\recovery\Test-UiExports.ps1 -RunRoot $latestRun.FullName
.\recovery\Test-QuickStartExports.ps1 -RunRoot $latestRun.FullName
```

RCPTT **2.6.1** проверяет 42 прежних сценария и новый quick start (всего 43) без пропусков: JDT-компиляцию
и загрузку классов, импорт, запуск/остановку, трассы, результаты, CSV/JSON, графики,
анимацию и game5. Отдельная проба создаёт, отображает и освобождает SWT/AWT frame на JDK 21.
Перед UI-прогоном проверяются SHA-256 плагинов обоих загруженных инструментов.

[GitHub Actions](.github/workflows/legacy-build.yml) настроен на эту матрицу:
пустой кэш, offline-повтор, ZIP/JUnit/логи; ручной `run_ui` включает UI и SWT/AWT.
Результаты платформы — в [STAGE4.md](recovery/STAGE4.md), библиотек и упаковки —
в [STAGE5.md](recovery/STAGE5.md). CI дополнен упаковкой и smoke, UI проверяет ZIP;
локальные изменения конфигурации не означают нового удалённого запуска CI.
Исторический успешный CI этапа 3 проверял прежнюю платформу, а не эту матрицу.

Исходная сборка JDK 8 / Mars / Xtext 2.9.2 и её lock-файлы сохранены в истории
на коммите `fe02d189`. Команды и свидетельства — [STAGE3.md](recovery/STAGE3.md).

## Документация и передача

[Первая модель на Windows](docs/user_guide/quick_start.html),
[HTML-справка](docs/index.html), [архитектура и выпуск](docs/development.md).
Шесть полных HTML-примеров проверяются обычной JUnit-сборкой: четыре исполняются, две анимации компилируются.
Отдельная проверка локальных ссылок требует Python 3.9+:

```powershell
python .\recovery\Test-Documentation.py --output .build/documentation-links.json
```

Ожидается `errors: []`. Внешние адреса перечисляются отдельно, сеть не используется.
Для запуска только UI quick start добавьте `-Tests '*docs_quickstart*'` к команде
`Invoke-RcpttTests.ps1` для установленного дистрибутива выше. Текст модели берётся
непосредственно из HTML, проверяются `.res`, `.trc`, CSV и JSON; численные точки проверяет `Test-QuickStartExports.ps1`.

Исторические команды Java 8, Jenkins/Nexus и `set-git-version` вынесены в
[отдельный архив](docs/history/build-legacy.md); исходное описание Linux/Neon —
в [исторический README](docs/history/README-legacy.md).
