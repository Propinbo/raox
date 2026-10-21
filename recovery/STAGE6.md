# Этап 6: документация и передача

Дата: 21 октября 2026 года. Статус: **выполнен**.
Исходный HEAD: `fe02d189dbef399a6f5d3afa10cc3bdceb3f7e7b`, ветка
`codex/stage3-reproducibility`. На момент завершения этапа 6 изменения этапов 4–6
оставались локальными; последующая передача через Git отмечается в [STATE](STATE.md).
Публикация релиза этим этапом не выполнялась.

## Результат

- [Локальная HTML-точка входа](../docs/index.html) перечисляет все 22 страницы.
  Справка работает с диска, сторонние скрипты и стили локальные. Внешние GIF
  заменены на явно обозначенные ссылки; CSS больше не загружает tinyurl.
  На каждой прежней странице sidebar ведёт к новой точке входа.
- [Windows quick start](../docs/user_guide/quick_start.html) описывает требования,
  инструменты, сборку, распаковку ZIP, новый workspace, создание `hello`,
  мониторинг, запуск, ожидаемые `.res`/`.trc` и пять точек CSV/JSON.
- [Руководство разработчика](../docs/development.md) содержит архитектуру,
  две стадии генерации, работу с Eclipse/PDE, отладку/JDWP, диагностику,
  форматы данных, правила проверок и подготовку выпуска.
- [README](../README.md) и [Maven-инструкция](../build-with-maven.md) теперь
  описывают текущую Windows / Java 21 платформу. Старые Java 8/Neon,
  Linux и Jenkins/Nexus-команды сохранены в [архиве README](../docs/history/README-legacy.md)
  и [архиве сборки](../docs/history/build-legacy.md).
- [Test-Documentation.py](Test-Documentation.py) проверяет локальные ссылки,
  anchors, изображения, CSS и JS-навигацию, полноту каталога и отсутствие
  внешних встраиваемых ресурсов в HTML. Внешние ссылки перечисляются без запросов.
  В CI добавлена эта проверка; Markdown-изменения теперь тоже запускают workflow.
- `DocumentationExamplesTest` читает код прямо из HTML: quick start, оба урока
  и logging исполняются; две полные анимации компилируются. Результаты и трассы
  уроков сравниваются с текстом документации целиком. Это пять новых JUnit,
  всего **38**. Тесты не содержат копий моделей.
- Новый RCPTT `docs_quickstart` выполняет действия из инструкции с текстом
  из HTML; полный набор теперь **43**. `Test-QuickStartExports.ps1` независимо
  сверяет числа экспорта с руководством. Счётчики и команды обновлены в CI.

## Что обнаружили проверки

Первый JUnit-прогон обнаружил разницу порядка строк `.res`: текущий вывод ставит
`Last value` перед `Mean`. Документация исправлена под фактический формат;
числа и трассы двух учебных моделей совпали без изменений runtime.

Первый UI-прогон выявил недостающий шаг перед CSV/JSON: команды экспорта доступны,
пока открыт график этого показателя. Добавлен явный шаг Plot и в инструкцию,
и в RCPTT; проверка не заменена прямым вызовом API.

Финальный полный UI-прогон дал 42/43: тест импорта остался на странице выбора
мастера после отдельного Next. В тесте выбранный мастер теперь активируется
двойным кликом. Проверка последовательности game5 → импорт → Stop повторена
отдельно; исходный полный отчёт сохраняется вместе с результатом повтора.

Уточнено описание горизонта модели звонков: `currentTime >= 480` проверяется
после модельного шага, поэтому в итог входят событие в `486.85470956869307`
и 11-й звонок. Сохранены прежняя семантика и значения статистик.

## Проверки

Чистая копия создана из всех доступных исходников Git, включая локальные новые
файлы, без `.git`, `.build`, `target` и `.class`. Исходный инвентарь и SHA-256 —
[source snapshot](evidence/stage6-source-snapshot.json). Финальные команды:

```powershell
.\recovery\Initialize-Platform.ps1 -IncludeUi
& '.build/stage6 clean source/recovery/Invoke-PlatformBuild.ps1' `
    -ToolchainRoot .build/platform-tools -CacheRoot .build/platform-m2 `
    -LogRoot .build/stage6-final-build-evidence -Clean -Offline
.\recovery\New-WindowsDistribution.ps1 -RepoRoot '.build/stage6 clean source' `
    -ToolchainRoot .build/platform-tools -OutputRoot .build/stage6-distribution
$smoke = .\recovery\Invoke-DistributionSmoke.ps1 `
    -ArchivePath .build/stage6-distribution/raox-3.9.0-windows-x86_64.zip
.\recovery\Invoke-SwtAwtProbe.ps1 -ApplicationRoot $smoke.application `
    -LogRoot .build/stage6-swt-awt
.\recovery\Invoke-RcpttTests.ps1 -JavaHome (Join-Path $smoke.application jre) `
    -RunnerRoot .build/platform-tools/rcptt -AutRoot $smoke.application `
    -PluginsRoot (Join-Path $smoke.application plugins) -InstalledDistribution `
    -LockRoot recovery/platform -LogRoot .build/stage6-final-ui
$run = Get-ChildItem .build/stage6-final-ui -Directory | Sort-Object Name | Select-Object -Last 1
.\recovery\Test-UiExports.ps1 -RunRoot $run.FullName
.\recovery\Test-QuickStartExports.ps1 -RunRoot $run.FullName
python .\recovery\Test-Documentation.py --output recovery/evidence/stage6-documentation-links.json
```

| Проверка | Результат и свидетельство |
| --- | --- |
| Чистые исходники, offline `clean verify` | Код 0, все 11 модулей, 38 JUnit, 0 ошибок/пропусков. [JSON](evidence/stage6-clean-build.json), [лог](evidence/stage6-clean-build.log), [HTML-примеры](evidence/stage6-junit/TEST-ru.bmstu.rk9.rao.tests.unit.DocumentationExamplesTest.xml). |
| Сохранность продукта | 811/811 классов идентичны контрольному этапу 5. [Сравнение](evidence/stage6-class-comparison.json). |
| Самостоятельный ZIP из свежего p2 | 1 362 файла, 385 449 360 байт. [SHA-256 и пути](evidence/stage6-distribution.json). |
| Native launcher и Unicode-путь | Код 0 без JAVA_HOME и Java в PATH; приложение в пути с кириллицей/пробелами. [JSON](evidence/stage6-native-smoke.json). |
| SWT/AWT | Java 21.0.12.1 / SWT 4970, код 0. [Лог](evidence/stage6-swt-awt.log). |
| Новый workspace и полный UI-набор | Полный прогон 42/43, затем game5/import/stop 3/3 после исправления UI-теста. Все 43 случая подтверждены. [Полный JUnit](evidence/stage6-rcptt/results.junit.xml), [повтор](evidence/stage6-rcptt/import-followup/results.junit.xml), [сводка](evidence/stage6-rcptt/verification.json). |
| Экспорт quick start | Last value 4, четыре события до t=3, CSV/JSON совпали по всем пяти точкам. [JSON](evidence/stage6-rcptt/quickstart-validation.json), [.res](evidence/stage6-rcptt/docs-quickstart.res), [.trc](evidence/stage6-rcptt/docs-quickstart.trc). |
| Локальные ссылки и ресурсы | 22 HTML-страницы, ошибок нет. [JSON](evidence/stage6-documentation-links.json). |

Каталог справки и sidebar quick start дополнительно просмотрены в браузере через
localhost. Прямой `file://` запрещён политикой встроенного браузера, поэтому
открытие с диска проверено по локальным ссылкам и ресурсам, без отдельного UI-прогона.
Инструменты и заполненный кэш этапа 5 использованы повторно; новая холодная
загрузка и отдельная машина на этапе 6 не проверялись.

## Передаваемые исходники

`assembly/target/handoff/raox-3.9.0-stage6-source.zip` содержит текущие исходники
вместе с локальными изменениями этапов 4–6. В архиве есть `SOURCE-MANIFEST.json`
с SHA-256 каждого файла; `.git`, инструменты, кэши и результаты сборки исключены.
Контрольная сумма самого архива записывается в `recovery/evidence/stage6-handoff.json`.
После чистой сборки уточнялись только документация, её проверка и CI;
входы компилятора и текст проверенных HTML-моделей остались прежними.
[Проверка различий](evidence/stage6-post-build-source-delta.json).

## Границы передачи

Проверка первого запуска автоматизирована реальным RCPTT через элементы интерфейса
в новом workspace. Отдельный прогон человеком без знакомства с проектом не проводился.
Описание PDE/JDWP подготовлено по коду и конфигурации, интерактивная PDE-сессия
не входит в подтверждённые результаты этого этапа.

Две полные анимации из справочника проверены компилятором; интерактивный Bird
с внешними спрайтами не прогонялся. Встроенная UI-анимация, графики и game5
проверяются RCPTT. Короткие фрагменты синтаксического справочника не объявлены
самостоятельными проверенными моделями. Внешние сайты не проверялись на доступность.

ASCII-ограничение пути исходников, отсутствие пользовательского CLI,
непроверенный Linux и [ограничения зависимостей](THIRD-PARTY.md) сохраняются.
Современные исходники находятся в ветке `codex/stage3-reproducibility` fork;
ветка по умолчанию `release/current` остаётся исторической. Публикация релиза —
отдельное действие после подтверждения нового CI на той же версии.
