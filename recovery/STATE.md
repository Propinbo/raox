# Rao X: состояние для продолжения

Обновлено 21 октября 2026 года. Этапы 1 и 2 завершены. Локальная часть этапа 3
выполнена; завершающий GitHub Actions run в fork готовится. Подробности —
[STAGE3.md](STAGE3.md), история проверок — [STAGE1.md](STAGE1.md) и [STAGE2.md](STAGE2.md).

## Репозиторий и исходная точка

- Каталог: `C:\Users\propinbo\Documents\raox`.
- Upstream: `https://github.com/LeKaitoW/raox.git`, исходная ветка `release/current`.
- Базовый HEAD: `80f0c44d2c6541ea43a4fdc9ff3598fa9e9e01fc`.
- Пользователь поручил создать fork: создан `https://github.com/Propinbo/raox`,
  сохранены все шесть веток и 34 тега. [Подтверждение](evidence/stage3-fork.jpg).
- Исходная рабочая ветка восстановления: `recovery/initial-audit`.
  Изменения этапов 1–3 подготавливаются к отправке в отдельную ветку `codex/stage3-reproducibility`.

## Изменения этапа 3

1. Добавлен модуль `raox.target`: 152 точных p2 IU, `win32/win32/x86_64`, JavaSE-1.8.
   Оба родительских POM используют один target; широкие p2 repositories удалены.
2. Maven Wrapper 3.3.4 (`only-script`) скачивает Maven 3.3.9 и проверяет SHA-256.
   `Initialize-Toolchains.ps1` получает Temurin 8u504-b01, при `-IncludeUi` — Eclipse/RCPTT.
3. Зафиксированы SHA-256 152 p2-bundle, 354 Maven-бинарников, четырёх metadata p2,
   1296 файлов плагинов UI Eclipse и 935 файлов runner.
4. `Invoke-LegacyBuild.ps1` изолирует кэши и settings, проверяет JDK/Maven, 32 теста,
   ZIP и зависимости; сохраняет результат каждой транспортной попытки, поддерживает
   `-RequireEmptyCache` и `-Offline`, восстанавливает переменные окружения.
5. Исправлен offline fallback старого Tycho для XZ metadata через проверенные
   content/artifacts JAR в его штатном формате кэша. Версии платформы не обновлялись.
6. `.github/workflows/legacy-build.yml`: Windows Server 2022, сборка с пустым кэшем,
   offline-повтор, ZIP/JUnit/логи; отдельный ручной job с 42 RCPTT и проверкой экспортов.
   Удалён устаревший `.travis.yml`. Изменения только Markdown/evidence не запускают CI.
7. Обновлены README/инструкция сборки/roadmap, добавлены отчёт и свидетельства этапа 3.

Изменения этапов 1–2 сохранены: совместимый Maven-classpath генератора/Xtend,
ANTLR без тайм-аута, упаковка runtime, Unicode/модельные тесты, исправления порядка
результатов, экспорта, трассы, таймера, запуска до компиляции и мастера game5.
Грамматика, математические библиотеки и семантика симулятора не переносились.

## Последние подтверждённые проверки

| Проверка | Результат |
| --- | --- |
| Чистые исходники и пустой Maven/p2/wrapper-кэш | Код 0; 10 модулей, 32 JUnit, 0 failures/errors/skipped. Две транспортные ошибки сохранены, третья попытка завершилась успешно. [JSON](evidence/stage3-cold-build.json), [лог](evidence/stage3-cold-build.log) |
| `clean verify -Offline` | Код 0; 32 JUnit, проверены все 152 p2 и 354 Maven-бинарника. [JSON](evidence/stage3-offline-build.json), [лог](evidence/stage3-offline-build.log) |
| Полный UI-прогон | Код 0; 42/42 RCPTT, без ошибок/пропусков. [JUnit](evidence/stage3-rcptt/results.junit.xml), [HTML](evidence/stage3-rcptt/results.html) |
| CSV/JSON | Пять одинаковых правильных точек; остановка трассы при t=3. [Проверка](evidence/stage3-rcptt/export-validation.json) |
| Классы новой сборки | 858 `.class` побайтово совпали с архивом, прошедшим UI. [Сравнение](evidence/stage3-class-comparison.json) |
| Отдельная машина / GitHub CI | Пока не подтверждено; fork создан, workflow подготовлен. |

Исходники копировались в `.build/clean source` без `target`/`.class`;
[манифест](evidence/stage3-source-snapshot.json). Новый кэш — `.build/final-m2`;
старые кэши туда не копировались. Пакеты и инструменты скачивались по HTTPS.
Подробности транспортных ошибок и проверки защиты SHA-256 — в `STAGE3.md`.

## Команды

Из корня репозитория, Windows PowerShell 5.1 или 7:

```powershell
.\recovery\Initialize-Toolchains.ps1
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify -RequireEmptyCache
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify -Offline
```

`-RequireEmptyCache` применяется только к новому/пустому кэшу. По умолчанию
инструменты находятся в `.build/tools`, Maven/p2/wrapper — в `.build/m2`,
логи — в `.build/evidence`. Для уже проверенного локального кэша:

```powershell
.\recovery\Invoke-LegacyBuild.ps1 -CacheRoot .build/final-m2 -Clean -Goal verify -Offline
```

Исходники должны находиться в ASCII-пути; пробелы и Unicode-имена внутри моделей
проверены. Кэш должен быть выделенным для этой сборки. Архивы содержат плагины;
самостоятельный новый дистрибутив относится к этапу 5. SHA ZIP/JAR меняется из-за
меток времени; неизменность 858 `.class` проверена отдельно.

## Следующий проверяемый шаг

Отправить изменения в fork `Propinbo/raox`, выполнить GitHub Actions `build` с
пустым кэшем и сохранить ссылку/отчёты. При успехе закрыть внешний критерий этапа 3,
обновить этот файл и roadmap. Этап 4 — согласованный перенос платформы с прежними
32 JUnit и 42 RCPTT; не обновлять одновременно JDK/Xtext и математические библиотеки.
