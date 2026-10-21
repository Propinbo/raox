# Rao X: состояние для продолжения

Обновлено 22 октября 2026 года. **Этапы 1–6 завершены; повторная проверка перед основной веткой пройдена.**
[Roadmap](ROADMAP.md), [отчёт этапа 6](STAGE6.md),
[локальная справка](../docs/index.html), [первая модель](../docs/user_guide/quick_start.html).

## Репозиторий и точка передачи

- Каталог: `C:\Users\propinbo\Documents\raox`.
- Upstream: `https://github.com/LeKaitoW/raox.git`, исходный HEAD —
  `80f0c44d2c6541ea43a4fdc9ff3598fa9e9e01fc`.
- Fork: `https://github.com/Propinbo/raox`.
- Основная ветка передачи: `fork/release/current`. Базовый HEAD до общего коммита этапов 4–6 —
  `fe02d189dbef399a6f5d3afa10cc3bdceb3f7e7b`.
- Этапы 4–6 объединены в `e43d43d7696fa47f19d8e4fc1fa7a2af205248b7`.
  [Java 21 CI 39650169800](https://github.com/Propinbo/raox/actions/runs/39650169800)
  успешно выполнил холодную сборку, offline-повтор и упаковку.
- 22 октября 2026 года повторно проверен этот код из чистой Git-копии:
  38 JUnit, 43/43 RCPTT одним прогоном, ZIP/native launcher, SWT/AWT и экспорт.
  [Отчёт](RECHECK-2026-10-22.md).
- По прямому поручению пользователя публикация идёт в основную ветку fork
  `release/current`, без force-push. Постоянное правило сохранено в [AGENTS.md](../AGENTS.md).
  Исходники доступны обычным clone fork; отдельная рабочая ветка больше не нужна.

## Текущая версия

Rao X 3.9.0, Temurin 21.0.12.1+1, Maven 3.9.11, Tycho 4.0.13,
Eclipse 2025-09 / 4.37, Xtext/Xbase/Xtend 2.40.0, Windows x64.
Gson 2.14.0, JSON.simple 4.0.1, JGraphX 4.2.2, JFreeChart 1.5.6,
SWTGraphics2D 1.1.0, Commons Math 3.6.1. Полный p2 и самостоятельный ZIP
с Java создаются без старого Nexus. Seed, числа, исторические трассы и результаты сохранены.

Этап 6 обновил README/build-with-maven, HTML-справку и навигацию, добавил
`docs/index.html`, `docs/user_guide/quick_start.html`, `docs/development.md`,
архив старых инструкций в `docs/history`, пять JUnit-проверок шести HTML-примеров,
RCPTT quick start, проверку ссылок/экспорта и команды CI. Runtime не менялся;
811 классов продукта совпали с контрольным этапом 5.

## Последние подтверждённые проверки

Полный свежий набор и команды — в [повторной проверке 22 октября](RECHECK-2026-10-22.md).
Исторические свидетельства этапов ниже сохраняются по первоначальным путям.

| Проверка | Результат |
| --- | --- |
| Чистая копия, offline `clean verify` | Код 0, 11 модулей, 38 JUnit, без ошибок и пропусков. [JSON](evidence/stage6-clean-build.json). |
| Шесть полных HTML-примеров | Четыре исполняются, две анимации компилируются. [JUnit](evidence/stage6-junit/TEST-ru.bmstu.rk9.rao.tests.unit.DocumentationExamplesTest.xml). |
| Установленный ZIP, новый AUT workspace | Повтор 22 октября: 43/43 одним прогоном, 0 ошибок/пропусков. [JUnit](evidence/recheck-2026-10-22-rcptt/results.junit.xml). |
| Первая модель из инструкции | Last value 4, четыре события до t=3, все пять точек CSV/JSON совпали. [JSON](evidence/stage6-rcptt/quickstart-validation.json). |
| Локальная HTML-справка | 22 страницы, ссылки/anchors/ресурсы проверены, ошибок нет. [JSON](evidence/stage6-documentation-links.json). |
| Native launcher | Код 0 без системной Java, путь с кириллицей/пробелами. [JSON](evidence/stage6-native-smoke.json). |
| SWT/AWT | Java 21.0.12.1 / SWT 4970, код 0. [Лог](evidence/stage6-swt-awt.log). |
| Продукт без изменения поведения | 811/811 классов совпали с этапом 5. [JSON](evidence/stage6-class-comparison.json). |

Пустой кэш локально подтверждён этапом 5; этот этап использовал заполненный кэш
и проверил новую копию исходников. Детали предыдущих проверок — в [STAGE5](STAGE5.md).

## Команды и артефакты

Обычная сборка из корня переданных исходников (PowerShell 7):

```powershell
.\recovery\Initialize-Platform.ps1 -IncludeUi
.\recovery\Invoke-PlatformBuild.ps1 -Clean
.\recovery\New-WindowsDistribution.ps1
```

Все команды UI, документации, отладки и выпуска — в
[build-with-maven](../build-with-maven.md) и [руководстве разработчика](../docs/development.md).

- ZIP этапа 6: `.build/stage6-distribution/raox-3.9.0-windows-x86_64.zip`.
  SHA-256 и размер — [distribution.json](evidence/stage6-distribution.json).
- Передача исходников с локальными изменениями:
  `assembly/target/handoff/raox-3.9.0-stage6-source.zip`.
  Внутри `raox/SOURCE-MANIFEST.json` с SHA-256 каждого файла, без .git/.build/target.
  Сведения о самом архиве сохраняются рядом со свидетельствами в `stage6-handoff.json`.
- Чистая сборка: `.build/stage6 clean source`; плагины и p2 находятся в её `assembly/target`
  и `raox.repository/target`. Логи — `.build/stage6-final-build-evidence`.
- UI: `.build/stage6-final-ui`, экспортированные свидетельства — `recovery/evidence/stage6-rcptt`.
- Инструменты: `.build/platform-tools`, кэш: `.build/platform-m2`.
  Команды с точными параметрами и кодами завершения — в [STAGE6](STAGE6.md).

## Ограничения и следующий шаг

Исходники должны лежать в ASCII-пути; установленное приложение, workspace и
Unicode-модели проверены. Упаковка требует PowerShell 7, Windows 10 1903+ / 11 x64.
Linux на новой платформе не проверялся; пользовательского CLI для запуска моделей пока нет.
Оставшиеся advisory HTTP/Jetty и встроенный модифицированный JSON учтены в
[THIRD-PARTY](THIRD-PARTY.md).

Первый запуск проверен автоматически через UI. Отдельного человеческого прогона,
интерактивной PDE/JDWP-сессии и интерактивного Bird с внешними спрайтами не было.
Ссылки внешних сайтов не проверялись на доступность; просмотр HTML через браузер
выполнен на localhost, прямой file:// блокируется политикой встроенного браузера.

Следующий шаг вне завершённого roadmap — подготовить выпуск по инструкции.
Изменения после успешных обязательных проверок отправляются в `fork/release/current`;
статус нового CI проверяется отдельно по точному SHA. Правило — в [AGENTS.md](../AGENTS.md).
