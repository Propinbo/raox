# Rao X: первичное обследование

Дата: 20 октября 2026 года. Обследованы исходники, конфигурация сборки, встроенные библиотеки, документация и метаданные GitHub. План работ — [ROADMAP.md](ROADMAP.md), точка продолжения — [STATE.md](STATE.md).

Это исторический отчёт этапа 0. Позднее в тот же день завершён этап 1: полная сборка плагинов восстановлена, 7 JUnit-тестов проходят. Актуальные изменения и свидетельства — [STAGE1.md](STAGE1.md); исходные логи обследования сохранены.

## Исходная точка

| Параметр | Значение |
| --- | --- |
| Репозиторий | [LeKaitoW/raox](https://github.com/LeKaitoW/raox) |
| Локальная папка | `C:\Users\propinbo\Documents\raox` |
| Ветка по умолчанию | `release/current` |
| Коммит исходников | `80f0c44d2c6541ea43a4fdc9ff3598fa9e9e01fc` |
| Последний коммит этой ветки | 28 января 2023 года, слияние изменения лицензии |
| Последнее изменение программы после релиза | 25 декабря 2017 года, горизонтальная прокрутка трассы |
| Последний опубликованный релиз на момент проверки | [3.9.0, 27 октября 2017 года](https://github.com/LeKaitoW/raox/releases/tag/3.9.0) |
| Коммит тега 3.9.0 | `c99a18b1f1bb130c5f8ac24a27a635433dee5f43` |
| Лицензия основного проекта | MIT; условия сторонних компонентов требуют отдельного учёта |
| Рабочая ветка обследования | `recovery/initial-audit` |

Ветка `release/current` отличается от 3.9.0 только файлом `LICENSE` и изменением `TraceView.java`. `origin/master` указывает на коммит релиза, поэтому выбор обычного имени `master` вместо ветки по умолчанию дал бы более старую исходную точку.

GitHub не помечает репозиторий архивным. Это технический флаг; по истории выбранной ветки функциональная разработка остановилась в 2017 году. В этой работе исходники приложения и исходные POM не изменялись; добавлены материалы в `recovery/`. Изменения не коммитились и не отправлялись на GitHub.

## Что это за программа

Rao X — собственный язык имитационного моделирования `.rao` на Xtext/Xbase. Исходная грамматика и Xtend-код формируют JVM-модель; при работе в Eclipse из неё получаются Java-классы модели, использующие runtime симуляции. Представления Eclipse показывают трассу, результаты, графики, анимацию и поиск на графе.

```mermaid
flowchart LR
    A[Модель .rao] --> B[Xtext/Xbase и RaoJvmModelInferrer]
    B --> C[Java-классы модели и JDT]
    C --> D[Runtime симуляции]
    D --> E[Результаты, трасса, графики, анимация]
```

Отдельная цепочка сборки проекта: `Rao.xtext` + `GenerateRao.mwe2` → сгенерированный parser/EMF-код → Xtend/Java → OSGi-плагины → архив `assembly`.

| Каталог | Назначение и важные точки входа |
| --- | --- |
| `ru.bmstu.rk9.rao` | Грамматика `src/ru/bmstu/rk9/rao/Rao.xtext`, MWE2 workflow, валидатор, scoping, `jvmmodel/RaoJvmModelInferrer.xtend` и компиляторы конструкций языка |
| `ru.bmstu.rk9.rao.lib` | Симулятор `simulator/Simulator.java`, планировщик событий, ресурсы, процессы, поиск, случайные последовательности, результаты и база трассы |
| `ru.bmstu.rk9.rao.ui` | Eclipse UI; `execution/BuildUtil.java`, `ModelInternalsParser.java`, `ExecutionJobProvider.java` связывают проект, классы модели и симулятор |
| `ru.bmstu.rk9.rao.tests` | Шесть Java-файлов, в том числе четыре метода JUnit `@Test`; тестируется часть процессов и трассы |
| `ru.bmstu.rk9.rao.rcptt` | Отдельные UI/модельные сценарии и эталоны; каталог не включён в Maven reactor |
| `ru.bmstu.rk9.rao.sdk` | Eclipse feature с составом плагинов |
| `ru.bmstu.rk9.rao.plugins/raox-game5` | Встроенный плагин пятнашек, шаблон модели и JSON.simple |
| `assembly` | Упаковка плагинов и дополнительной копии runtime JAR без версии |
| `deploy` | Историческая упаковка с внешним Eclipse и получением `LATEST` из кафедрального Nexus; не часть корневого reactor |
| `docs` | Сохранившаяся HTML-справка с локальными CSS/JS и изображениями |

В репозитории есть `RaoStandaloneSetup`, но готовый независимый CLI для полного запуска моделей при обследовании не найден. Основная оркестрация выполнения сейчас находится в Eclipse UI; вывод о возможности её выделения в headless-компонент — архитектурное предложение, ещё не реализация.

Всего в исходной точке: 585 отслеживаемых файлов, 275 Java, 24 Xtend, одна грамматика Xtext и один MWE2 workflow. Машиночитаемая сводка — [inventory.json](evidence/inventory.json).

## Инструменты и зависимости

| Компонент | Что указано в проекте | Где подтверждено |
| --- | --- | --- |
| Java | JavaSE-1.8 | `META-INF/MANIFEST.MF`, README, тестовый POM; также захардкожено в `BuildUtil.java` |
| Eclipse target | Mars, `201506241002` | Корневой `pom.xml`; README при этом предлагает Neon |
| Xtext / Xtend | 2.9.2 | Свойство `xtext-version` корневого POM |
| Tycho | 0.23.0 | Свойство `tycho-version` корневого POM |
| Генерация | Старые `org.eclipse.xtext.generator.*` fragments | `GenerateRao.mwe2` |
| JUnit | 4.12 | POM тестового модуля |
| Maven Surefire | 2.19 | Тот же POM; отдельный Tycho Surefire имеет `skip=true` |
| Commons Math | 3.6 | Встроенный JAR в runtime; версия подтверждена manifest |
| Gson | 2.6.2 | Встроенный JAR в UI и manifest |
| JGraphX | 3.3.1.1 | Manifest `jgraphx.jar` и старый скрипт получения библиотек |
| JFreeChart | 1.0.19, в том числе SWT и experimental | Имена JAR, manifest основного JAR, Bundle-ClassPath |
| JCommon | 1.0.23 | Имя JAR и Bundle-ClassPath |
| JSON.simple | 1.1.1 | Встроенный JAR game5 и его manifest |
| Log4j API | Импорт `org.apache.log4j` | Manifests и сгенерируемый код; фактическая версия платформенного bundle ещё требует фиксации |

Список восьми встроенных JAR, размеров и SHA-256 — [DEPENDENCIES.csv](DEPENDENCIES.csv). Это инвентаризация файлов, не полный SBOM: транзитивные зависимости p2/Maven и встроенный исходный код ещё не разобраны полностью. Проверка advisory/CVE в этой сессии не проводилась.

Значения `bundle-version="2.8.4"` или `"2.7.1"` без верхней границы в OSGi manifests не означают требование строго равной версии. Их нельзя автоматически считать конфликтом с Xtext 2.9.2 или Rao X 3.9.0. При переносе всё равно потребуется согласовать диапазоны и набор bundle.

## Документация и тесты, которые удалось сохранить

- 20 HTML-страниц: 11 страниц справочника, два учебных примера, пять страниц руководства пользователя и две страницы отладки. Точки входа: `docs/reference/base_types_and_functions.html` и `docs/tutorial/call_center_single_operator.html`.
- CSS, JavaScript и изображения находятся рядом с HTML. Проверены 128 локальных `href`/`src` в HTML: отсутствующих целей не найдено. Динамические ссылки JavaScript, CSS imports и якоря этой проверкой не охвачены; [отчёт](evidence/docs-link-check.json).
- `README.md` описывает ручной импорт в Eclipse и генерацию; `build-with-maven.md` — старую Maven/Jenkins-сборку. Команды установки Oracle JDK через старый PPA требуют замены в новой инструкции.
- В RCPTT: 38 файлов `.test`, 14 файлов `.rao.template`; во всём проекте 18 `.rao.template`, 17 `.trc.etalon` и один `.res.etalon`. Некоторые сценарии используют общие либо создаваемые модели, поэтому число шаблонов не обязано совпадать с числом сценариев.
- Четыре JUnit-метода — процессы и парсер трассы. `LinearProcessTest` ожидает `RUNTIME_ERROR` и допускает отклонение времени меньше `1e16`; такой допуск почти ничего не проверяет. Причина ожидания ошибки пока не выяснена.
- `tycho-surefire-plugin` отключён, но отдельный `maven-surefire-plugin` настроен запускать unit-тесты. Нельзя делать вывод, что отключены вообще все тесты, или считать `package` эквивалентом запуска RCPTT.

## Проверка внешних источников

20 октября 2026 года HTTP HEAD-запросы получили 200 для `p2.index` и `content.jar` архивных Mars и Xtext 2.9.2 по HTTPS. Проверенные HTTP-адреса перенаправляются на HTTPS. Maven также начал реально скачивать плагины этой платформы. Все плагины целевой платформы на момент первоначальной проверки ещё не считались подтверждёнными только по ответу HEAD.

`raox.ru` по HTTP и HTTPS не разрешился по DNS из текущего окружения. Это наблюдение с этого компьютера, а не доказательство недоступности сайта из любой сети. Полные адреса и ответы — [endpoint-checks.json](evidence/endpoint-checks.json).

Скачан архив плагинов [raox-3.9.0.zip](https://github.com/LeKaitoW/raox/releases/download/3.9.0/raox-3.9.0.zip), размер 8 735 945 байт, SHA-256:

```text
319978c996f1d3a8d165dc57038ac718e966a7d4ad05b3a60b52aa1ea0c11221
```

В нём пять JAR: язык, UI, game5, runtime с версией и runtime без версии. Это плагины, а не готовая установка Eclipse. Сам архив и переносимые инструменты находятся в рабочем каталоге сессии; точные пути в `STATE.md`. Полный дистрибутив Windows x64 около 357 МБ не скачивался. Бинарники из релиза не запускались.

Метаданные релиза и репозитория сохранены в [github-snapshot.json](evidence/github-snapshot.json).

## Диагностика сборки

Изначально `java` и `mvn` отсутствовали в PATH. В `JAVA_HOME` был указан Android Studio JBR 25.0.3; считать его подходящим окружением для этой сборки нельзя без отдельной проверки.

Подготовлены отдельные JDK Temurin 8u504-b01 x64 и Apache Maven 3.3.9. Maven выбран как близкий по эпохе к Tycho 0.23, потому что исходный проект не фиксирует точную версию Maven. Современное обновление JDK 8 уменьшает число посторонних проблем с сертификатами, но это не точное воссоздание исторического CI. Контрольные суммы инструментов и команды — в `STATE.md`.

Проверка исходной конфигурации началась с отдельного пустого Maven-кэша и пустого пользовательского settings-файла. Последующий `package` использовал тот же диагностический кэш. Глобальные настройки Java/Maven не менялись.

| Проверка | Фактический результат |
| --- | --- |
| `mvn validate` | Код 0, `BUILD SUCCESS`, все девять проектов reactor; первый запуск занял 5 минут 16 секунд |
| Компиляция runtime в `package` | Успешна, создан `ru.bmstu.rk9.rao.lib/target/ru.bmstu.rk9.rao.lib-3.9.0.jar` |
| Генератор языка в `package` | Код процесса 1, `UnsupportedClassVersionError` в MWE2 |
| Компиляция всего языка/UI, unit-тесты, RCPTT, итоговый архив, запуск Eclipse | Не подтверждены; проверка завершилась раньше |

Первая фатальная ошибка:

```text
org/eclipse/core/runtime/OperationCanceledException
class file version 61.0; Java Runtime recognizes versions up to 52.0
```

Класс из загруженного `org.eclipse.platform:org.eclipse.equinox.common:3.21.0` действительно имеет major version 61: это дополнительно установлено чтением заголовка `.class` внутри JAR. По [спецификации JVM](https://docs.oracle.com/javase/specs/jvms/se17/html/jvms-4.html#jvms-Table-4.1-A), 61 соответствует Java 17, 52 — Java 8. [Проверенный файл и SHA-256](evidence/incompatible-generator-class.json).

Лог показывает загрузку EMF common 2.46.0, EMF ecore 2.43.0, Eclipse core runtime 3.35.0 и Equinox common 3.21.0 через Maven для `exec-maven-plugin`. Это отдельный от p2 набор зависимостей. Следующее действие — зафиксировать совместимый classpath генератора. Предупреждения Codehaus сопровождали разрешение зависимостей, но фатальная ошибка этого запуска — несовместимый формат класса.

Журналы: [validate](evidence/raox-validate-original.log), [package](evidence/raox-package-original.log); [сводка](evidence/build-results.json). `validate` не компилирует приложение и не запускает тесты. Исправления исходной конфигурации в этой сессии ещё не выполнялись.

## Основные препятствия и риски

1. **Воспроизводимость.** Нет `.target`, Maven Wrapper и явно заданных target environments. При диагностике Tycho сообщает: `No explicit target runtime environment configuration. Build is platform dependent.` Это подтверждённое свойство конфигурации.
2. **Разные исторические окружения.** POM использует Mars, README — Neon, Travis упоминает Oxygen. Точное окружение последнего релиза пока не восстановлено.
3. **Старая генерация и Unicode.** README прямо описывает ошибки `RULE_ANY_OTHER` и предлагает повторную генерацию. Дефект в текущем окружении ещё необходимо воспроизвести.
4. **Windows-пути.** `runtimeProject=/${project.basedir}` и `file://${project.basedir}` в Maven могут потребовать адаптации; это гипотеза до результата генерации.
5. **Зависимость выполнения от Eclipse.** Код запуска использует JDT, workspace, UI и загрузчик классов. Выделение запуска без интерфейса не сводится к замене одной команды.
6. **Совместимость моделей.** Commons Math, порядок событий и формат трассы влияют на численные результаты. Массовое обновление до контрольных тестов затруднит поиск причины изменений.
7. **Графика.** `GraphShell.java` использует `SWT_AWT.new_Frame`; JFreeChart имеет отдельные SWT/experimental JAR. Требуется проверка на выбранных JDK и Windows.
8. **Упаковка.** В `deploy` есть `LATEST` и старый Nexus; этот путь нельзя принять за воспроизводимую схему выпуска. Скрипт получения JFreeChart использует изменяемый URL `latest`.
9. **Maven-classpath генератора.** `exec-maven-plugin` получает Xtext из Maven Central отдельно от Tycho/p2. В опубликованном `org.eclipse.xtext.parent:2.9.2` EMF задан диапазоном `(2.8,3.0)`, ANTLR — `[3.2,3.3)`. В исходном запуске `package` наблюдается перебор более новых EMF/Equinox и предупреждения о DNS Codehaus. Фиксация только p2 target platform не зафиксирует этот classpath.

## Источники для дальнейшего переноса

- [Исходная конфигурация проекта](https://github.com/LeKaitoW/raox/blob/80f0c44d2c6541ea43a4fdc9ff3598fa9e9e01fc/pom.xml) — первичный источник версий старой сборки.
- [Xtext: конфигурация генератора](https://eclipse.dev/Xtext/documentation/302_configuration.html#the-language-generator) — современная инфраструктура генерации введена в 2.9; документация рекомендует пошаговый перенос грамматики и настроек в новый каркас.
- [Tycho: target platform configuration](https://tycho.eclipseprojects.io/doc/main/target-platform-configuration/target-platform-configuration-mojo.html) — справочник для фиксации платформы и окружений; параметры следует сверять с выбранной версией Tycho.
- [Maven 3.8.1 release notes](https://maven.apache.org/docs/3.8.1/release-notes.html) — блокировка внешних HTTP Maven-репозиториев. Это дополнительный вопрос при обновлении Maven, а не доказательство того, что именно он ломает p2 в текущем запуске Maven 3.3.9.
