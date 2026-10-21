# Этап 3: воспроизводимость и CI

21 октября 2026 года. Базовый HEAD `80f0c44d2c6541ea43a4fdc9ff3598fa9e9e01fc`,
исходная рабочая ветка `recovery/initial-audit`.

**Статус: локальные критерии выполнены, удалённый CI-прогон готовится.**
После проверки доступа к исходному репозиторию пользователь поручил создать
fork. Создан [Propinbo/raox](https://github.com/Propinbo/raox) от
[LeKaitoW/raox](https://github.com/LeKaitoW/raox), с шестью ветками и 34 тегами.
Внешний критерий roadmap пока остаётся открытым до успешного GitHub Actions run.
[Первичная проверка доступа](evidence/stage3-github-access.json),
[подтверждение fork](evidence/stage3-fork.jpg).

## Зафиксированные входные данные

Оба родительских POM используют один модуль
[`raox.target`](../raox.target/raox.target.target), среду `win32/win32/x86_64`
и execution environment `JavaSE-1.8`. Широкие p2-репозитории из POM удалены:
target явно перечисляет 152 точных IU, без версии `0.0.0`.
122 bundle взяты из Mars `201506241002`, 30 — из релиза Xtext `2.9.2`.
Их версии и SHA-256 находятся в [p2-bundles.lock.json](p2-bundles.lock.json).

| Компонент Maven/p2-платформы | Версия |
| --- | --- |
| JDK | Temurin 8u504-b01, Windows x64 |
| Maven / Wrapper | 3.3.9 / 3.3.4, `only-script` |
| Tycho | 0.23.0 |
| Equinox OSGi | 3.10.100.v20150529-1857 |
| Core runtime | 3.11.0.v20150405-1723 |
| JDT core | 3.11.0.v20150602-1242 |
| SWT / Windows x64 fragment | 3.104.0.v20150528-0211 |
| EMF Ecore p2 | 2.11.0.v20150512-0501 |
| Xtext / Xbase / Xtend lib p2 | 2.9.2.v201603040440 |

Maven-classpath генератора и Xtend остаётся отдельным от p2. Совместимые явные
версии EMF из этапа 1 сохранены; 354 Maven JAR/ZIP и их SHA-256 зафиксированы в
[maven-artifacts.lock.csv](maven-artifacts.lock.csv), проверяются скриптом
`Test-DependencyLocks.ps1`. Используйте выделенный кэш сборки: посторонние
бинарники из прежних экспериментов считаются отличием от lock-файла.
Старые диапазоны в транзитивных POM ещё могут вызывать загрузку кандидатных POM
и metadata; новые либо изменённые JAR/ZIP не должны незаметно менять сборку.

UI-платформа зафиксирована отдельно: Eclipse 4.7.1, Xtext
`2.12.0.v20170518-0959`, Xbase `2.12.0.v20170519-0752`, RCPTT 2.2.0.
SHA-256 исходных ZIP заданы в [toolchains.lock.json](toolchains.lock.json),
состав плагинов — в [eclipse-plugins.lock.csv](eclipse-plugins.lock.csv)
и [rcptt-plugins.lock.csv](rcptt-plugins.lock.csv). Перед UI-прогоном проверяются
1296 файлов Eclipse и 935 файлов runner. Это фиксация двух исторических окружений;
их перенос на единую современную платформу относится к этапу 4.

## Запуск из новой копии

```powershell
.\recovery\Initialize-Toolchains.ps1
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify -RequireEmptyCache
```

Первая команда скачивает JDK с проверкой SHA-256. Вторая использует Apache Maven
Wrapper с фиксированными URL/версией и `distributionSha256Sum`, собственный
`MAVEN_USER_HOME` и Maven/p2-кэш. По умолчанию всё помещается в `.build/`,
который игнорируется Git. Системные установки и PATH не меняются.
После заполнения кэша повторная проверка без сети Maven:

```powershell
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify -Offline
```

`JAVA_HOME`, `MAVEN_OPTS`, `MAVEN_USER_HOME` восстанавливаются после завершения,
включая ошибку. Используются одинаковые проектные user/global settings:
системные Maven settings и старый Codehaus не являются скрытыми условиями.
Maven-зависимости загружаются только из HTTPS Maven Central, p2 — из двух
точных HTTPS release-сайтов; p2-зеркала и локальные артефакты Tycho отключены.

У загрузок есть тайм-ауты и ограниченные повторы. Каждая попытка Maven записывается
отдельно, её код и причина попадают в JSON. Автоматически повторяются только
явные ошибки транспорта (DNS/соединение/тайм-аут). Ошибка генерации, компиляции
или теста не является основанием повторять сборку. `-NetworkRetries 0` отключает
повторы Maven; `Initialize-Toolchains.ps1` допускает три попытки загрузки каждого ZIP.

Исходники по-прежнему требуют ASCII-пути; пробелы поддерживаются. Ограничение
ANTLR и проверки Unicode-имён сохранены. Нужен доступ в сеть к зафиксированным
источникам; бинарное зеркало не включено в Git.

## Проверки

Холодная сборка выполнена из `.build/clean source` (ASCII-путь с пробелом).
До первого запуска в копии не было `target` и `.class`, а `.build/final-m2`
отсутствовал. Исходники копировались из рабочих файлов Git без игнорируемых
результатов сборки; старые Maven/p2/wrapper-кэши туда не переносились.

| Проверка | Результат |
| --- | --- |
| Холодный `clean verify`, 13:29–13:39 МСК | Код 0, 10 модулей, 32 JUnit; две сохранённые сетевые ошибки и успешная третья попытка в одной команде с изначально пустым кэшем. [JSON](evidence/stage3-cold-build.json), [лог](evidence/stage3-cold-build.log) |
| `clean verify -Offline`, 13:47–13:48 МСК | Код 0, 32 JUnit, без ошибок/пропусков. Все 152 p2-bundle и 354 Maven-бинарника совпали с lock-файлами. [JSON](evidence/stage3-offline-build.json), [лог](evidence/stage3-offline-build.log) |
| Скомпилированные классы | Все 858 `.class` в четырёх плагинах холодной сборки побайтово совпали со сборкой, прошедшей UI-прогон. [Сравнение](evidence/stage3-class-comparison.json) |

После холодной сборки обнаружен дефект offline-кэша Tycho 0.23: Mars metadata
скачивается в XZ, а fallback offline ищет только `content/artifacts + URI.hashCode()
+ .jar/.xml`. `Initialize-P2MetadataCache.ps1` после online-сборки сохраняет четыре
проверенных `content.jar`/`artifacts.jar` в формате, который понимает fallback.
Их URL/имена кэша/SHA-256 закреплены в [p2-metadata.lock.json](p2-metadata.lock.json).
Offline-режим только проверяет эти файлы, без загрузок. Версии Tycho/p2 не менялись.

- Полный `clean verify` с прежним кэшем: все 10 reactor-модулей, 32 JUnit,
  без failures/errors/skipped; проверены все 152 p2-bundle.
  [JSON](evidence/stage3-warm-build.json), [лог](evidence/stage3-warm-build.log).
- Полный RCPTT: **42/42**, код 0, без failures/errors/skipped.
  [JUnit](evidence/stage3-rcptt/results.junit.xml),
  [HTML](evidence/stage3-rcptt/results.html), [хеши плагинов](evidence/stage3-rcptt/run.json).
  Использован заново скачанный Eclipse и прежний runner; заново скачанная копия
  runner имеет идентичные 935 файлов плагинов.
- CSV/JSON: пять правильных одинаковых точек, трасса заканчивается при `t=3`;
  [проверка](evidence/stage3-rcptt/export-validation.json).
- JDK, Eclipse и RCPTT заново скачаны по HTTPS и совпали с фиксированными SHA-256;
  [сводка](evidence/stage3-toolchains.json).
- Wrapper отвергает неверную SHA-256 Maven до запуска Maven;
  [проверка](evidence/stage3-wrapper-guard.json).
- Непустой кэш отвергается при `-RequireEmptyCache`, окружение сохраняется;
  [проверка](evidence/stage3-cache-guard.json).
- Проверка p2 отвергает повреждённый JAR, PowerShell-файлы успешно разобраны;
  [проверка](evidence/stage3-script-validation.json).
- YAML workflow разобран, оба job и три триггера на месте, все Actions закреплены
  SHA коммитов; [проверка](evidence/stage3-workflow-validation.json).

Первый полный холодный запуск остановился на `NoRouteToHostException` при
загрузке JDT из Eclipse. Сохранены [лог](evidence/stage3-cold-network-failure.log)
и [JSON](evidence/stage3-cold-network-failure.json). После этого добавлены настройки
IPv4 и отдельные тайм-ауты/повторы ECF. Новый холодный запуск использует новый
пустой каталог; частично скачанный первый кэш в него не копировался.

Здесь воспроизводимость означает фиксированные входные версии, проверяемые
бинарные зависимости и повторяемые результаты сборки/моделей. Побитовая
идентичность ZIP/JAR не заявляется: старые упаковщики записывают время сборки.

## CI и оставшийся внешний критерий

[`legacy-build.yml`](../.github/workflows/legacy-build.yml) заменяет неработающий
Travis-файл. На `push`, `pull_request` и `workflow_dispatch` job `build` использует
Windows Server 2022, скачивает JDK и выполняет `clean verify` с пустым Maven/p2/wrapper
кэшем, затем повторяет сборку offline. Кэш намеренно не восстанавливается. Сохраняются плагины, ZIP, Surefire XML
и логи/JSON даже при ошибке. Разрешение токена — только `contents: read`.

Отдельный job `ui` включается параметром `run_ui: true` ручного запуска,
получает четыре плагина из `build`, скачивает UI-инструменты, выполняет 42 RCPTT
и проверяет содержимое экспортов. Его HTML/JUnit/логи/экспорты сохраняются отдельно.
Команды ручного UI-прогона есть в [инструкции сборки](../build-with-maven.md).

Для полного закрытия этапа осталось отправить в fork текущие изменения этапов 1–3
и получить успешный run `build` на другом компьютере.
Затем сохранить URL run/артефакты в этом отчёте и обновить `STATE.md`/roadmap.
Не следует объявлять этап полностью закрытым только по наличию YAML или локальных
проверок. Создание fork устраняет первоначальное отсутствие права записи в upstream.

Конфигурация target соответствует
[документации Tycho](https://wiki.eclipse.org/Tycho/Target_Platform/),
SHA-256 Wrapper — [документации Apache Maven](https://maven.apache.org/tools/wrapper/index.html),
настройки ECF — [документации p2](https://wiki.eclipse.org/Equinox/p2/TransportDebugging).
