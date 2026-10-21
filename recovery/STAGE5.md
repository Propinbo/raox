# Этап 5: библиотеки и самостоятельный Windows x64-дистрибутив

21 октября 2026 года. HEAD `fe02d189`, ветка `codex/stage3-reproducibility`.
Изменения этапов 4 и 5 локальные; новые коммиты и удалённый CI не запускались.

**Статус: выполнен.** 33 JUnit и 42 RCPTT без ошибок и пропусков;
самостоятельный ZIP запускается вне checkout с собственной Java.

## Библиотеки

Вместо восьми исторических JAR используются шесть проверяемых бинарников и
фиксированные исходники SWT-адаптера. Координаты, лицензии, SHA-256, исходники,
использование и решения по каждому старому JAR — в [THIRD-PARTY.md](THIRD-PARTY.md),
[новом инвентаре](DEPENDENCIES.csv) и [lock-файле](embedded-libraries.lock.json).
Исходный инвентарь сохранён в [DEPENDENCIES-baseline.csv](DEPENDENCIES-baseline.csv).

| Компонент | Изменение |
| --- | --- |
| Gson | 2.6.2 → 2.14.0 |
| JSON.simple | 1.1.1 → Clifton Labs 4.0.1; namespace, парсер, исключение и запись через `toJson()` адаптированы |
| JGraphX | 3.3.1.1 → 4.2.2; upstream завершил развитие, это явно учтено |
| JFreeChart | 1.0.19 → 1.5.6; перенесены Args, DatasetUtils, RendererUtils, RectangleEdge и dataset index crosshair |
| JCommon / experimental | Удалены: нужные классы вошли в JFreeChart, experimental приложением не использовался |
| SWT-адаптер | Исходники `b4762fbe8fc5bae1ae7097f55b099117dee76abe`, без demos; собираются внутри UI bundle |
| SWTGraphics2D | Добавлен 1.1.0; SWT берётся из единой платформы |
| Commons Math | 3.6 → 3.6.1, с точным численным эталоном |

Gson, JSON.simple, JGraphX и графики сначала проверялись отдельно: по 32 прежних
JUnit. Перед заменой Commons Math на старой версии записаны SHA-256 последовательностей
8 × 1 000 значений: Uniform, Normal, Exponential, Triangular, Poisson с двумя
интенсивностями, непрерывная и дискретная гистограммы. Восемь отпечатков совпали
побитово; это закреплено отдельным `MathLibraryCompatibilityTest`. Теперь тестов 33.
Известное игнорирование seed гистограммами сохранено, как и порядок равновременных
событий и исторические трассы/результаты. [Проба](probes/MathFingerprint.java).

Старый `get_thirparty_libraries.sh`, скачивавший mutable latest по HTTP,
больше не возвращает старые JAR. Обычная сборка проверяет шесть бинарников и
32 файла исходников/лицензий; изменение JAR в отдельной копии отвергнуто.
[Отрицательная проверка](evidence/stage5-lock-negative.json).

## Упаковка

Добавлен Maven-модуль `raox.repository` (`eclipse-repository`). Tycho собирает
полный локальный p2-репозиторий с зависимостями и ZIP, feature включает все четыре
плагина Rao X. p2 director устанавливает в пустой каталог Eclipse Platform, JDT,
Xtend SDK и Rao SDK. Xtend нужен для `XTEND_CONTAINER` модельных проектов.
Загруженный Eclipse используется как build tool, его готовая установка не копируется.
Nexus, dropins и внешняя Java при запуске не нужны.

Архив: `assembly/target/windows-x64/raox-3.9.0-windows-x86_64.zip`.
Размер: 385 449 624 байта. SHA-256:
`4a975dc8f280c93a0694e1b78988d4574a016cc9a13d2674ce08e7d80ae60553`.
Он содержит приложение, полную Java 21, исходники LGPL-компонентов, лицензии,
проверяемый манифест файлов и сведения о происхождении launcher-файлов.
Запуск — `raox/eclipse.exe`; console launcher имеет отдельный `eclipsec.ini`.

Исторический ZIP из пяти JAR сохранён для совместимости. Его упаковка переведена
на Resources 3.3.1 / Assembly 3.7.1; неиспользуемый replacer и пустой JAR удалены.
Clean plugin обновлён до 3.4.1, build-helper тестов — до 3.6.1, JUnit — до 4.13.2.

При сборке полного p2 впервые понадобились native/root-архивы Eclipse. Основной
`download.eclipse.org/.../binary/` возвращал HTML «Temporary shutdown» вместо ZIP.
Проверка SHA-512 корректно остановила сборку. Используется зеркало **того же**
timestamp-релиза `https://ftp.fau.de/eclipse/releases/2025-09/202509101001/`;
служебный архив совпал с опубликованной SHA-256. Автовыбор зеркал отключён, проверки
сумм сохранены. Дополнительно зафиксированы 30 feature/native архивов.
[Диагностика](evidence/stage5-p2-mirror.json).

## Пути Windows

У исходных Windows EXE Java 21 воспроизведена потеря кириллицы до старта JVM:
`could not find java.dll`, `Unable to access jarfile ... ???????? ...`.
В копии дистрибутива 38 EXE получают `activeCodePage=UTF-8`. Действие локально
для процесса, системная локаль и исходная загруженная JDK не меняются.
[Механизм Microsoft](https://learn.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page),
[воспроизводимый скрипт](Enable-Utf8Launchers.ps1).

Манифест меняет PE-ресурсы EXE и исходные цифровые подписи больше не действительны;
`native-launchers.json` сохраняет исходную и новую SHA-256 каждого EXE. DLL и JAR
не меняются. Поддерживаемая цель — **Windows 10 1903+ / Windows 11 x64**.

Native smoke распаковывает ZIP в `%TEMP%/Rao X проверка ...`, проверяет все исходные
файлы, удаляет JAVA_HOME/JDK_HOME, оставляет в PATH только System32 и запускает
`eclipsec.exe`. Получены код 0 и четыре установленных корневых IU. JVM также
проверяется через UI из той же распакованной копии. После запуска p2 закономерно
переписывает три preference-файла профиля; повторная проверка UI допускает только
эти runtime-настройки, продолжая сверять плагины, JVM, EXE и остальные файлы.

## Проверки

| Проверка | Свидетельство |
| --- | --- |
| Отдельные обновления библиотек | `evidence/stage5-{gson,json,jgraphx,charts,math}-build.log` |
| Новая упаковка, 33 JUnit | [Лог](evidence/stage5-packaging-build.log) |
| Новые исходники, чистая offline-сборка, 33 JUnit | [JSON](evidence/stage5-clean-build.json), [лог](evidence/stage5-clean-build.log), [исходники](evidence/stage5-source-snapshot.json) |
| Зависимости новой сборки | 736 p2-bundle, 30 feature/native архивов, 383 Maven-бинарника |
| Содержимое плагинов чистой и установленной сборки | Все четыре совпали: [JSON](evidence/stage5-clean-plugin-comparison.json) |
| Скомпилированные классы | 811/811 совпали: [JSON](evidence/stage5-clean-class-comparison.json) |
| Стандартный кэш после переноса холодного набора | Offline, код 0, 33 JUnit: [JSON](evidence/stage5-default-build.json), [классы](evidence/stage5-default-class-comparison.json) |
| UI приложения и workspace в путях с кириллицей и пробелами | 42/42: [JUnit](evidence/stage5-rcptt/results.junit.xml), [HTML](evidence/stage5-rcptt/results.html), [пути](evidence/stage5-rcptt/paths.json) |
| CSV/JSON и анимация | Пять правильных одинаковых точек, трасса до t=3: [JSON](evidence/stage5-rcptt/export-validation.json) |
| Native launcher без системной Java | Код 0, все 1 362 файла проверены: [JSON](evidence/stage5-native-smoke.json) |
| SWT/AWT из готового продукта в пути с кириллицей | Java 21.0.12.1 / SWT 4970, код 0: [лог](evidence/stage5-swt-awt.log) |

Дополнительно новая копия исходников собрана с действительно пустыми
Maven/p2/Wrapper-кэшами: код Maven 0, 33 JUnit, 6 мин 56 с.
Первичная сверка инвентаря обнаружила 92 старых бинарника, остававшихся в прежнем
кэше после обновления Maven-плагинов. Lock пересоздан по холодному набору;
затем исключён Log4j 1.2.16, оставив 383 Maven-бинарника. Новая чистая копия
финальных исходников прошла offline с этим набором и полными SHA-256 проверками.
[Холодный лог](evidence/stage5-cold-build.log),
[первичная диагностика инвентаря](evidence/stage5-cold-inventory-bootstrap.json),
[исключение Log4j](evidence/stage5-log4j-exclusion.json).

После полного UI-прогона в ZIP уточнён только `THIRD-PARTY.md` и пересчитан
манифест; бинарники и конфигурации остались побайтово прежними.
Финальный ZIP повторно прошёл native smoke.
[Проверка различий](evidence/stage5-package-delta.json).

Тест создания Java-проекта адаптирован к каталогу wizard нового продукта:
прямой пункт `File/New/Java Project`, выбор перспективы не зависит от суффикса
`(default)`. Проверки модели и ожидаемые результаты не ослаблены. Game5 дополнительно
закрывает и повторно открывает сохранённый JSON после миграции парсера.

На длительной модели проверка Stop выявила переполнение очереди обновлений UI:
главный поток постоянно выполнял layout `StatusView`, а heap histogram содержал
2 697 `org.eclipse.swt.widgets.RunnableLock`. [Потоки](evidence/stage5-ui-starvation-threads.txt),
[histogram](evidence/stage5-ui-starvation-histogram.txt). `RealTimeUpdater` теперь
допускает только один ожидающий пакет обновлений; следующий пакет отображает
актуальное состояние. Модельное время, события и результаты не меняются.
Проверка Stop использует исходную кнопку toolbar; ожидания не заменены прямым
вызовом runtime API и не ослаблены.

## Advisory и границы

По точным старым версиям найден CVE-2022-25647 у Gson 2.6.2; новая версия его
не содержит по ответу OSV. Шесть новых встроенных JAR проверены отдельно.
Провайдер `org.apache.log4j` на платформе — **reload4j 1.2.26**, а не исходный
Log4j 1.x; manifests теперь ограничивают минимальную версию импорта.
Генерируемый Xtext-код всё ещё использует этот API, поэтому сохранён совместимый
провайдер из единой платформы.
Из Maven-моста ANTLR отдельно исключён `log4j:log4j:1.2.16`; classpath генератора
явно использует reload4j 1.2.26.

Транзитивная проверка фактического продукта и build-кэша нашла advisory у восьми
компонентов HTTP/Jetty платформы. Они сохранены как согласованная Eclipse 2025-09
матрица; причины, условия, полные advisory и ограничения проверки перечислены в
[THIRD-PARTY.md](THIRD-PARTY.md) и [отчёте OSV](evidence/stage5-dependency-audit/osv-results.json).
Итоговый SBOM содержит 856 компонентов, 782 Maven-сопоставления; выполнено
628 запросов по уникальным координатам и версиям, 74 компонента оставлены без
автоматического Maven-сопоставления. Старый `log4j:log4j` в этом наборе отсутствует.
Это **остаточный риск**, а не заявление об отсутствии уязвимостей. Встроенная
модифицированная JSON.org 2014 и неизвестное происхождение AbstractGenerator
также учтены отдельно; их нельзя объявить проверенными по точной Maven-версии.

Исходники по-прежнему требуют ASCII-пути генератора; пробелы и Unicode в моделях
проверяются, установленный продукт поддерживает кириллицу в пути. Linux не входит
в проверенную цель. Обновлённый CI конфигурирует ZIP/native smoke/UI, но в этой
сессии на GitHub не запускался. Этап 6 — документация и передача.

Команды сборки и запуска: [build-with-maven.md](../build-with-maven.md).
