# Этап 4: перенос платформы

21 октября 2026 года. Исходный HEAD — `fe02d189`, рабочая ветка
`codex/stage3-reproducibility`. Изменения этапа 4 пока локальные.

**Статус: выполнен.** Новая платформа собирается и исполняет контрольные модели:
32 JUnit и 42 RCPTT без ошибок/пропусков, чистая сборка с пустым кэшем и offline-повтор.
Трассы, результаты и численные ожидания сохранены. Все 783 класса чистой и offline-сборки
побайтово совпали со сборкой, прошедшей UI.

## Матрица

| Компонент | Зафиксированная версия |
| --- | --- |
| JDK, сборка и UI | Temurin 21.0.12.1+1, Windows x64 |
| Maven / Wrapper | 3.9.11 / 3.3.4 |
| Tycho | 4.0.13 |
| Eclipse | 2025-09 R / 4.37 |
| Xtext / Xbase / Xtend, Maven и UI | 2.40.0 / p2 2.40.0.v20250825-0355 |
| EMF Common / Ecore / XMI | 2.43.0 / 2.40.0 / 2.39.0 |
| EMF Codegen / Codegen Ecore | 2.27.0 / 2.43.0 |
| MWE2 / MWE | 2.23.0 / 1.17.0 |
| Guice | 7.0.0 |
| JDT, target и Maven-classpath Xtext | 3.43.0 |
| GEF Classic | bundle 3.23.0.202507261623, feature 3.25.0.202508011427 |
| RCPTT | 2.6.1 |

Выбрана согласованная матрица Eclipse 2025-09 для проверяемого перехода с Mars/Oxygen.
Это не заявление о самых новых версиях всех компонентов. Tycho 4.0.13 требует
Maven >= 3.9.0 и JDK >= 17; JDK 21 подходит также выбранному Eclipse.
[Требования Tycho](https://tycho.eclipseprojects.io/doc/4.0.13/tycho-compiler-plugin/plugin-info.html).
Xtend 2.40 сменил Maven groupId на `org.eclipse.xtext`:
[release notes](https://eclipse.dev/Xtext/releasenotes.html).

Target содержит пять точных корневых IU и единственный timestamp-репозиторий
`https://download.eclipse.org/releases/2025-09/202509101001/`.
Все 338 p2-bundle и 398 Maven-бинарников дополнительно фиксируются SHA-256 в
`platform/`; старые lock-файлы этапа 3 сохранены отдельно от новой матрицы.
Maven-classpath генератора и Xtend явно фиксирует те же EMF и JDT.
Встроенный компилятор Tycho — ECJ 3.41; он создаёт проверяемый Java 21 bytecode.

## Последовательность переноса

1. Контрольный `clean verify -Offline` на прежней матрице: код 0, 32 JUnit,
   проверены 152 p2 bundle и 354 Maven-бинарника.
2. Отдельно заменён workflow, ещё на Xtext 2.9.2/JDK 8: вместо
   `org.eclipse.xtext.generator.Generator` используется
   `org.eclipse.xtext.xtext.generator.XtextGenerator / StandardLanguage`.
   Этот API появился в Xtext 2.9 и остаётся современной инфраструктурой генератора:
   [документация](https://eclipse.dev/Xtext/documentation/302_configuration.html#the-language-generator).
   Пройдены 32 JUnit и все 42 прежних RCPTT; CSV/JSON и остановка трассы совпали.
   [Изолированный diff](evidence/stage4-generator-migration.patch),
   [сборка](evidence/stage4-generator-build.log),
   [JUnit](evidence/stage4-generator-junit/),
   [RCPTT](evidence/stage4-generator-rcptt/results.junit.xml).
3. Перенесены JDK, Maven, Tycho и единая платформа Xtext 2.40.
   Настроены URI workflow через `project.baseUri`, независимый Maven-classpath,
   `org.eclipse.xtext.testing`, версия Xtend Maven plugin и явный JUnit 4 provider.
4. Согласованы JavaSE-21 в target, POM, пяти manifests, Eclipse `.classpath`
   и `BuildUtil`. Созданные и импортируемые модельные проекты получают JRE 21
   и Java 21 compiler options. Headless javac использует `--release 21`.
5. Добавлены SHA-256 инструментария/платформы, команды загрузки и сборки,
   проверка bytecode 65 всех 783 классов четырёх плагинов и проба SWT/AWT.
   CI переведён на ту же матрицу. Самостоятельный дистрибутив остаётся этапом 5.

Грамматика, восемь встроенных JAR, seed, эталоны трасс и результатов не изменены.
Перегенерированы parser/EMF/Guice-классы; content-assist lexer переместился из
`ui.contentassist` в `ide.contentassist`. IDE-генерация помещена в существующий UI
bundle, чтобы сохранить состав устанавливаемых плагинов. Добавлены стандартные
`RaoIdeModule`/`RaoIdeSetup`. Пустой `RaoScopeProvider`
расширяет генерируемую базу; собственные runtime/compiler/type-system bindings сохранены.

## Разобранные несовместимости

- Генератор по умолчанию создавал Xtend-stubs рядом с имеющимися Java-модулями.
  Для модулей выбран Java, для существующих Xtend validator/label/outline/content assist
  оставлен Xtend. Эти дубликаты удалены; пользовательские реализации сохранены.
- Старые `additional.bundles` ссылались на удалённый `org.eclipse.xtext.generator`,
  ASM 5 и инструменты MWE/EMF. Генератор теперь использует собственный Maven-classpath;
  неиспользуемые build/runtime-требования удалены.
- GEF теперь возвращает `List<? extends GraphicalEditPart>`. Прежняя переменная
  `List<ru.bmstu.rk9.rao.ui.gef.EditPart>` скрывала небезопасное приведение.
  Цикл использует `org.eclipse.gef.GraphicalEditPart` и прежний `instanceof BlockEditPart`.
- Surefire автоматически выбрал JUnit Platform из-за транзитивных Jupiter-зависимостей
  и выполнил ноль старых JUnit 4. Указан `surefire-junit47:3.5.4`; итоговый прогон
  действительно выполняет 32 проверки. Скрипт отвергает другой счётчик и пропуски.
- Одна диагностическая загрузка Maven остановилась на чтении ASM 9.6 с `repo1.maven.org`.
  Поток ожидал HTTP-данные, а не выполнял модель. Процесс остановлен, журнал сохранён;
  использован основной `repo.maven.apache.org`, для нового Maven добавлены тайм-ауты
  Aether connector. Тесты и генерация по такой причине автоматически не маскируются.

## Подтверждённые проверки

| Проверка | Результат и свидетельство |
| --- | --- |
| Контрольная старая платформа | Код 0, 32 JUnit, 152 p2 / 354 Maven. [JSON](evidence/stage4-baseline-build.json) |
| Новый workflow на старой платформе | Код 0, 32 JUnit и 42 RCPTT. [Сборка](evidence/stage4-generator-build.log), [UI](evidence/stage4-generator-rcptt/run.json) |
| Java 21, полный reactor | Код 0, все 10 модулей, 32 JUnit. [Лог](evidence/stage4-platform-build.log) |
| Чистые исходники + пустой кэш | Код 0, 32 JUnit; 5 мин 48 с, путь с пробелами. [JSON](evidence/stage4-cold-build.json), [лог](evidence/stage4-cold-build.log), [манифест исходников](evidence/stage4-source-snapshot.json) |
| `clean verify -Offline` | Код 0, 32 JUnit, 338 p2 и 398 Maven SHA-256. [JSON](evidence/stage4-offline-build.json), [лог](evidence/stage4-offline-build.log) |
| Стандартный кэш `.build/platform-m2` | Код 0, offline, 32 JUnit, все хеши совпали. [JSON](evidence/stage4-default-build.json), [лог](evidence/stage4-default-build.log) |
| Новый Eclipse / RCPTT / JDK 21 | Код 0, 42/42, failures/errors/skipped = 0. [JUnit](evidence/stage4-rcptt/results.junit.xml), [HTML](evidence/stage4-rcptt/results.html), [версии и хеши](evidence/stage4-rcptt/run.json) |
| Экспорт и анимация | CSV/JSON: пять одинаковых правильных точек, трасса заканчивается при t=3. [JSON](evidence/stage4-rcptt/export-validation.json) |
| SWT/AWT | Создание, отображение и освобождение embedded Frame на Java 21.0.12.1 / SWT 4970, код 0. [Лог](evidence/stage4-swt-awt.log) |
| Побайтовое сравнение с UI-сборкой | 783/783 `.class` совпали в чистой, offline и окончательной сборке. [Чистая](evidence/stage4-cold-class-comparison.json), [окончательная](evidence/stage4-default-class-comparison.json) |
| Защита lock-файлов | Изменение содержимого копии p2 JAR отвергнуто. [JSON](evidence/stage4-lock-negative.json) |

Холодный запуск использовал `.build/stage4 clean source` без `target`, `.class` и
сгенерированных результатов, с новым `.build/stage4-cold-m2`. Кэш не переносился
из старой сборки. После фиксации инвентаря и offline-проверки проверенный кэш
перемещён в стандартный `.build/platform-m2`; стандартная команда повторно прошла.
Пробный кэш сохранён в `.build/stage4-trial-m2`. Финальный ZIP —
`assembly/target/raox-3.9.0.zip`; проверены его состав, совпадение копий runtime и
bytecode 65 всех 783 классов. SHA-256 архива находится в окончательном JSON.

## Команды запуска

```powershell
.\recovery\Initialize-Platform.ps1
.\recovery\Invoke-PlatformBuild.ps1 -Clean
.\recovery\Invoke-PlatformBuild.ps1 -Clean -Offline

.\recovery\Initialize-Platform.ps1 -IncludeUi
.\recovery\Invoke-SwtAwtProbe.ps1
.\recovery\Invoke-RcpttTests.ps1 `
    -JavaHome .build/platform-tools/jdk-21.0.12.1+1 `
    -RunnerRoot .build/platform-tools/rcptt `
    -AutRoot .build/platform-tools/eclipse/eclipse `
    -LockRoot recovery/platform `
    -PluginsRoot assembly/target/plugins -LogRoot .build/stage4-ui
```

После UI-прогона: `Test-UiExports.ps1 -RunRoot <каталог прогона>`.
Полные инструкции — [build-with-maven.md](../build-with-maven.md).

## Границы проверки

Поддерживаемая цель — Windows x64. Источники по-прежнему проверяются в ASCII-пути,
в том числе с пробелами; Unicode внутри моделей проверяется тестами.
Установку самостоятельного дистрибутива в произвольные пути и обновление
математических/графических JAR этот этап не подменяет. Конфигурация CI обновлена
локально; новый удалённый GitHub run в этой сессии не запускался.
