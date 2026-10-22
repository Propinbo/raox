# Разработка Rao X

Проверенная цель: Windows x64, Temurin 21.0.12.1+1, Maven 3.9.11, Tycho 4.0.13,
Eclipse 2025-09 / 4.37 и Xtext/Xbase/Xtend 2.40.0. Начните с
[первой модели](user_guide/quick_start.html) и [команд сборки](../build-with-maven.md).
Состояние передачи, локальные изменения и ограничения — в [STATE](../recovery/STATE.md).

## От текста модели до симуляции

```text
.rao → Xtext parser / EMF model → проверка типов Xbase
     → RaoJvmModelInferrer / entity compilers → src-gen/*.java
     → JDT → bin/*.class → ModelInternalsParser / class loader
     → Simulator / EventScheduler / DPTManager
     → Database / результаты → представления Eclipse
```

| Модуль | Назначение и точки входа |
| --- | --- |
| `ru.bmstu.rk9.rao` | Грамматика `src/ru/bmstu/rk9/rao/Rao.xtext`, workflow `GenerateRao.mwe2`, `jvmmodel/RaoJvmModelInferrer.xtend`, `validation`, `typesystem`, `compiler`. |
| `ru.bmstu.rk9.rao.lib` | Runtime без UI: `simulator`, очередь `event/EventScheduler`, активности `dpt`, ресурсы, распределения `sequence`, результаты `result`, сериализация `database`. |
| `ru.bmstu.rk9.rao.ui` | Мастер проекта, classpath, JDT-сборка, загрузка модели и UI. `execution/StartExecutionHandler`, `BuildJobProvider`, `ExecutionJobProvider`, `ModelInternalsParser`; `simulation`, `trace`, `results`, `plot`, `animation`. |
| `ru.bmstu.rk9.rao.plugins/raox-game5` | Дополнительная игровая модель и её UI. |
| `ru.bmstu.rk9.rao.tests` | JUnit, компиляция моделей без UI через тестовый `HeadlessModel`. |
| `ru.bmstu.rk9.rao.rcptt` | Тесты установленного интерфейса, контексты, шаблоны и эталоны. Не Maven-модуль. |
| `raox.target`, `ru.bmstu.rk9.rao.sdk` | Зафиксированная p2-платформа и состав feature продукта. |
| `raox.repository`, `assembly` | Полный локальный p2 и ZIP плагинов; PowerShell-скрипт устанавливает из p2 самостоятельный Windows ZIP. |

Пути Java/Xtend в таблице отсчитываются от `src/ru/bmstu/rk9/rao` соответствующего
модуля (у runtime — `src/ru/bmstu/rk9/rao/lib`).
Мастер Rao X создаёт проект с Java/Xtext nature, `src-gen`, JavaSE-21, Xtend
container и runtime JAR. Автоматическая сборка генерирует Java при сохранении `.rao`.
Запуск ждёт сборку и проверяет ошибки, затем `ModelInternalsParser` собирает
метаданные, начальные ресурсы, результаты, активности и `init()`.
`CurrentSimulator` хранит текущую симуляцию; `Simulator` исполняет события и
активности, проверяет `terminateCondition()` и отправляет уведомления UI.
Мониторинг управляет подробностью записи в базу и трассу.

Графические `.proc` обрабатывает отдельный process editor. Это не синтаксис `.rao`.
Тестовый `HeadlessModel` использует настоящий генератор, javac и runtime,
но не является поддерживаемым пользовательским CLI. Запуск модели из терминала
как отдельная команда продукта пока не реализован.

## Генерация исходников

Различайте генерацию самого языка и генерацию конкретной модели.

1. В Maven-фазе `generate-sources` модуля языка запускается MWE2
   `GenerateRao.mwe2` через `exec-maven-plugin` с отдельным зафиксированным classpath.
   `XtextGenerator / StandardLanguage` создаёт parser, lexer, EMF и UI-код.
   Затем компилируются Xtend и Java. Используйте полный `Invoke-PlatformBuild.ps1 -Clean`:
   этот путь проверяет Unicode в обоих lexer и parser.
2. В workspace пользователя Xtext-builder превращает `.rao` в `src-gen/*.java`;
   JDT создаёт `.class` в выходном каталоге проекта.

Не исправляйте сгенерированный код: изменяйте `Rao.xtext`, `jvmmodel/*.xtend`,
ручные расширения или исходник модели и повторяйте генерацию. Git уже исключает
`target`, `bin`, модель EMF и другие генерируемые каталоги. Причину первого сбоя
MWE2 сохраняйте в логе; повторять генерацию до случайного успеха не требуется.
Исходники языка должны находиться в ASCII-пути; это ограничение не распространяется
на Unicode-идентификаторы моделей и пути установленного приложения.

## Работа в Eclipse и отладка

Сначала выполните Maven-сборку. Для разработки плагинов используйте Eclipse
с PDE, JDT, Xtext/Xtend 2.40 и JDK 21; bootstrap Eclipse загружается командой
`Initialize-Platform.ps1 -IncludeUi`. Импортируйте существующие проекты из корня
checkout через `File → Import → General → Existing Projects into Workspace`.
Откройте `raox.target/raox.target.target` и установите его активной target platform
через `Set as Active Target Platform`, дождитесь разрешения зависимостей.
Создайте конфигурацию `Run → Run Configurations → Eclipse Application` с JRE 21
и отдельным runtime workspace; для точек останова запускайте её через Debug.
Это рабочая процедура для PDE, отдельный интерактивный PDE-прогон этапа 6 не проводился.

Для отладки установленного приложения без настройки PDE можно добавить JDWP
в отдельный запуск из PowerShell, оставляя терминал открытым:

```powershell
& C:\work\raox-app\raox\eclipse.exe -data C:\work\raox-debug-workspace `
    -vmargs '-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=localhost:5005'
```

В Eclipse разработчика подключитесь через `Remote Java Application`, host localhost,
port 5005, с соответствующими исходниками. Для ошибок компиляции смотрите Problems
и Java в `src-gen`. Для сбоя запуска — Error Log и `<workspace>/.metadata/.log`.
Точки останова ставьте в `StartExecutionHandler`, `ModelInternalsParser`,
`Simulator` и методе события в сгенерированном классе. Для сообщения из модели
используйте `log(...)`, вывод виден в Console; [пример](debug/logger.html).
Трасса помогает проверить порядок событий, а не только последнее значение.

## Трассы, результаты и экспорт

Включите корень модели в Monitoring Configuration **до запуска**.
`Model → Export Trace Output → Regular` сохраняет `<проект>.trc`,
`Model → Export Results` — `<проект>.res` в корень проекта. Текст — UTF-8.
Регулярный формат трассы создаёт `ui/trace/Tracer`, исторический вариант — `LegacyTracer`.
Полная таблица кодов — в [справке трассировки](debug/trace.html).

| Код | Значение |
| --- | --- |
| `ES` | Начало трассы/симуляции и остановка с причиной. |
| `EI` | Выполнение события: `EI 3.0 Tick[3]`. |
| `EB`, `EF`, `ER` | Начало/конец операции и выполнение правила. |
| `RC`, `RK`, `RE` | Создание, изменение и удаление ресурса. |
| `V` | Наблюдаемое значение результата в указанный момент времени. |

Время — `double` модельных единиц, единицу выбирает автор модели.
Условие `currentTime >= 480` проверяется на шагах симуляции: событие может
выполниться после 480. Учебные звонки завершаются в `486.85470956869307`, а не
строго в 480; последнее пришедшее событие уже учтено. Это сохранённая семантика.
Порядок равновременных событий не является устойчивым контрактом;
правила совместимости, seed и допуски — в [STAGE2](../recovery/STAGE2.md).

`.res` — текстовый вывод `ResultsParser`: полное имя вида
`проект.модель.показатель`, затем строки `  <статистика>: <значение>`.
`LastValueStatistics` даёт только `Last value`; статистики по умолчанию у числового
источника добавляют Mean, Standard deviation и varcoef. Их конкретные численные
правила исторические; не переинтерпретируйте varcoef как стандартную формулу
без отдельного изменения и численной проверки. Детали — в `lib/result`.

В Collected Objects выберите `модель → Results → показатель`:
сначала откройте график через контекстное меню Plot. Пока он открыт, повторно
выберите показатель в Collected Objects и используйте Export to CSV / Export to JSON.
CSV имеет заголовок `x,y`, JSON содержит массив объектов с полями `x` и `y`.
Это ряд измерений, а не JSON-представление `.res`. Две точки с одинаковым временем
допустимы (состояние до и после события); quick start даёт пять точек.
Пример JSON: `[{"x":0,"y":0},{"x":0,"y":1},{"x":1,"y":2},{"x":2,"y":3},{"x":3,"y":4}]`.

## Проверки и изменение поведения

Команды полностью приведены в [build-with-maven.md](../build-with-maven.md).

- 38 JUnit: runtime, parser/lexer и Unicode, генерация и компиляция,
  17 исторических моделей с точными трассами, порядок результатов и 8 000 значений
  Commons Math; шесть полных примеров непосредственно из HTML-справки
  (четыре с исполнением, две анимации с компиляцией).
- 43 RCPTT: прежние 42 проверки плюс quick start с новым проектом, запуском,
  `.res`/`.trc`, CSV и JSON. Каждый запуск получает новый AUT workspace.
- `Test-Documentation.py` (Python 3.9+) проверяет локальные ссылки, HTML anchors,
  изображения, CSS, JS-навигацию и полноту статического каталога. Внешние ссылки
  перечисляются отдельно и не требуют сети. Python нужен только для этой проверки.
- `Test-EmbeddedLibraries.ps1`, `Test-DependencyLocks.ps1` и
  `Test-WindowsDistribution.ps1` проверяют байты пакетов, а native smoke — launcher
  без системной Java. SWT/AWT имеет отдельную проверку.

Отчёты JUnit находятся в `ru.bmstu.rk9.rao.tests/target/surefire-reports`,
Maven — в `.build/platform-evidence`, RCPTT — в выбранном `-LogRoot`.
При добавлении JUnit обновите ожидаемое число в `Invoke-LegacyBuild.ps1`,
при добавлении UI-теста — в `Invoke-RcpttTests.ps1` и инструкции.
Полные HTML-модели помечены `id="model-source"` / `id="quickstart-source"` и двумя animation-id;
`DocumentationExamplesTest` компилирует их и сравнивает помеченные результаты/трассы.
Фрагменты справочника, содержащие `...` или отдельные объявления, самостоятельными
моделями не считаются. Не обновляйте исторические эталоны автоматически при сбое.

## Выпуск Windows-версии

Текущая версия — **3.9.0**. Следующая процедура описывает подготовку;
выпуск релиза этапом 6 не выполнялся. Последующая проверка и перенос в основную ветку
описаны в [отчёте 22 октября](../recovery/RECHECK-2026-10-22.md).
Состав и происхождение отдельного выпуска `3.9.0-java21` зафиксированы
в [паспорте релиза](../recovery/RELEASE-3.9.0-java21.md).

1. Зафиксируйте в Git окончательные исходники вместе с locks и лицензиями.
   Запишите commit/branch и состояние дерева. Основная ветка fork — `release/current`;
   порядок проверок и автоматической отправки задан в [AGENTS.md](../AGENTS.md).
2. При смене версии согласуйте все POM, `Bundle-Version` manifests, SDK feature,
   `raox.repository/category.xml`, assembly и строковые `3.9.0` в скриптах упаковки,
   проверки и CI. Найдите их через `rg -n '3\.9\.0' -g '*.xml' -g '*.MF' -g '*.ps1' -g '*.yml'`.
   Старый профиль `set-git-version` не покрывает новые Windows-скрипты и не является
   проверенной командой выпуска современной платформы.
3. Выполните чистую сборку из новой копии исходников с пустым отдельным кэшем,
   затем offline-повтор. Lock-файлы штатно проверяются, а не пересоздаются.
   При обновлении зависимости используйте отдельный кэш, пересмотрите лицензии,
   advisory и поведение, затем осознанно обновите locks. Основания текущего набора —
   в [THIRD-PARTY](../recovery/THIRD-PARTY.md).
4. Выполните проверку документации, упакуйте дистрибутив в новый OutputRoot,
   запустите native smoke и все RCPTT на этом установленном продукте, проверьте
   экспорт через `Test-UiExports.ps1` / `Test-QuickStartExports.ps1` и SWT/AWT.
   Сохраните логи и SHA-256.
5. Передавайте `raox-<версия>-windows-x86_64.zip`, `distribution.json`,
   архив `raox.repository-<версия>.zip`, исходники, отчёты и перечень ограничений.
   ZIP содержит Java, `licenses`, исходники LGPL и `THIRD-PARTY.md`.
   SHA-256 готового архива можно проверить `Get-FileHash -Algorithm SHA256 <путь>`.
6. После согласования выпуска создайте тег/релиз и загрузите артефакты.
   Имя и содержимое выпуска должны относиться к тому же commit, который прошёл CI.
   Обновите STATE и отчёт этапа; статус локального прогона отделяйте от удалённого.

Прежние Jenkins/Nexus/Linux-команды и предупреждение об Oracle JDK 8 сохранены
в [историческом README](history/README-legacy.md) и
[старой Maven-инструкции](history/build-legacy.md). Они не входят в проверенную
Windows / Java 21 процедуру. Linux на новой платформе не проверялся.
