# Сборка через maven

## Зафиксированная сборка Windows x64

Нужны Windows x64 и PowerShell 5.1 или 7. JDK Temurin **8u504-b01** загружается
скриптом, Apache Maven **3.3.9** — Maven Wrapper **3.3.4**. Системная установка
Java/Maven не требуется. URL и SHA-256 находятся в
[toolchains.lock.json](recovery/toolchains.lock.json) и
[maven-wrapper.properties](.mvn/wrapper/maven-wrapper.properties).
Из корня исходников:

```powershell
.\recovery\Initialize-Toolchains.ps1
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify
```

Путь к исходникам должен содержать только ASCII: например, `C:\work\raox`.
Пробелы в пути проверены. Кириллица в пути исходников ломает внутреннюю генерацию лексера
в старом ANTLR; скрипт сообщает об этом до запуска Maven. Русские и другие Unicode-имена
в `.rao` проверяются тестами и этим ограничением не затронуты.

Для собственных каталогов инструментов, кэша и отчётов:

```powershell
.\recovery\Initialize-Toolchains.ps1 -ToolchainRoot C:\raox-tools
.\recovery\Invoke-LegacyBuild.ps1 -ToolchainRoot C:\raox-tools -CacheRoot C:\raox-m2 `
    -LogRoot C:\raox-reports -Clean -Goal verify -RequireEmptyCache
```

По умолчанию выполняется `clean package` при `-Clean`, иначе `package`.
Для отдельных стадий доступны `-Goal validate` и `-Goal verify`.
`-RequireEmptyCache` отвергает непустой кэш. Для повторного запуска с ним уберите этот
флаг; `-Offline` проверяет сборку без сетевых обращений Maven после заполнения кэша.
Скрипт временно задаёт `JAVA_HOME`, `MAVEN_OPTS`, `MAVEN_USER_HOME`, использует отдельные Maven settings/кэш,
затем восстанавливает окружение. Журнал и JSON с кодом завершения, результатами тестов,
составом и SHA-256 архива сохраняются в `.build/evidence/`.
Инструменты по умолчанию лежат в `.build/tools/`, Maven/p2 и wrapper — в `.build/m2/`.
Все эти каталоги игнорируются Git. При сетевых ошибках допускаются три повтора;
каждая попытка имеет отдельный лог и запись в JSON. Ошибки генерации/компиляции/тестов
автоматически не перезапускаются. `-NetworkRetries 0` отключает сетевые повторы.

Maven использует только HTTPS Maven Central; старые транзитивные Codehaus-репозитории
заменяются через settings. p2 использует два точных release-сайта по HTTPS, без зеркал.
Все 152 bundle и их SHA-256 зафиксированы в
[p2-bundles.lock.json](recovery/p2-bundles.lock.json). Оба родительских POM используют
один [target](raox.target/raox.target.target), `win32/win32/x86_64`, JavaSE-1.8.
Локально установленные артефакты Tycho исключены.
Дополнительно проверяются 354 Maven JAR/ZIP из
[maven-artifacts.lock.csv](recovery/maven-artifacts.lock.csv). Кэш должен быть
выделенным для этой сборки. После online-запуска четыре p2 metadata-файла
сохраняются с проверкой SHA-256 для offline fallback старого Tycho.

Результат — **`assembly/target/raox-3.9.0.zip`**. В папке `raox/` находятся плагины
языка, runtime, UI, game5 и дополнительный `ru.bmstu.rk9.rao.lib.jar` без версии.
Скрипт проверяет состав архива и побайтовое совпадение двух копий runtime через SHA-256.
SDK feature собирается отдельно в `ru.bmstu.rk9.rao.sdk/target/`, как и в исходной сборке;
архив содержит плагины, без установленного Eclipse.

Проверено **32 JUnit-теста**, без ошибок и пропусков. Они включают реальную компиляцию
и выполнение всех 17 исторических моделей RCPTT, точное сравнение трасс и результатов,
UTF-8, неверный ввод и воспроизводимость seed. `LinearProcessTest` проверяет обоснованную
перегрузку без очереди при `t=50` и отдельное успешное выполнение.
RCPTT и запуск Eclipse выполняются отдельно. Инструменты можно получить тем же скриптом:

```powershell
.\recovery\Initialize-Toolchains.ps1 -IncludeUi
.\recovery\Invoke-RcpttTests.ps1 `
    -JavaHome .build/tools/jdk8u504-b01 `
    -RunnerRoot .build/tools/rcptt/eclipse `
    -AutRoot .build/tools/eclipse/raox-eclipse-3.9.0-win-x64 `
    -PluginsRoot assembly/target/plugins -LogRoot .build/ui-evidence
$latestRun = Get-ChildItem .build/ui-evidence -Directory | Sort-Object Name | Select-Object -Last 1
.\recovery\Test-UiExports.ps1 -RunRoot $latestRun.FullName
```

UI использует исторический Eclipse 4.7.1 / Xtext 2.12.0 и RCPTT 2.2.0;
его версии зафиксированы отдельно от Maven-платформы, включая хеши всех файлов плагинов.
Полный прогон обязан выполнить ровно 42 теста без пропусков.
[Подробности проверок поведения](recovery/STAGE2.md).

Jenkins, кафедральный Nexus и внешний каталог Eclipse для этой команды не требуются.
[Этап 3](recovery/STAGE3.md) содержит фактические результаты пустого кэша и ограничения.
[GitHub Actions](.github/workflows/legacy-build.yml) выполняет `verify` с пустым кэшем
на Windows Server 2022 и сохраняет ZIP, логи и JUnit. UI вынесен в отдельный job,
включаемый параметром `run_ui` при `workflow_dispatch`. Workflow не использует secrets,
Jenkins или Nexus; токен имеет только `contents: read`.
[Контрольный run](https://github.com/Propinbo/raox/actions/runs/39588936426) прошёл
холодную и offline-сборку на Windows Server 2022, по 32 JUnit. UI job в этом run
пропущен по условию; 42 RCPTT проверены локально. Ручной workflow_dispatch станет
доступен после попадания workflow в default branch; код оставлен в отдельной ветке fork.

## Исторические инструкции

Следующие команды сохранены для справки. Для контрольной сборки используйте команду выше.

## Общие положения
```
[export MAVEN_OPTS="-Xmx512M"]
[mvn initialize -N -Pset-git-version]
mvn [clean] package|deploy -Drepository-url=<url-to-repository-root> [-Pdebug]
```
- `export MAVEN_OPTS="-Xmx512M"` - Устанавливает максимальное количество выделяемой памяти.
Команда необходима, если сборка выдает ошибку `java heap space`. Под Windows `set MAVEN_OPTS="-Xmx512M"` или через настройки переменных среды.

- `mvn initialize -N -Pset-git-version` - Устанавливает версию бинарников на основе гита. Обязательная команда, если бинарники передаются пользователям.
 - `-N` или `--non-recursive` - Запускает только родительский pom.xml. Без этого флага версия поменяется, но сборка завершится с ошибкой, что критично для сборки на Дженкинсе.
 - `-Pset-git-version` - Определает и устанавливает версию на основе `git describe --tags`

- `mvn [clean] package` - Запускает очистку (`clean`) и следом за ней сборку (`package`) проекта, как если бы они запускались отдельно<br>
 ```
[mvn clean]
mvn package
```
`mvn clean` - Удаляет бинарники и содержимое папок `target`.<br>
`mvn package` - Запускает сборку.
Результаты сборки
 - архив с плагинами `assembly\target\rao-<version>-plugins.zip`. Например
    - `rao-2.8.0.12-gea41589-plugins.zip` для не релизной сборки
    - `rao-2.8.0-plugins.zip` для релизной

 - папка с плагинами
    - ```assembly\target\plugins\ru.bmstu.rk9.rao.lib-<version>.jar```
    - ```assembly\target\plugins\ru.bmstu.rk9.rao.ui-<version>.jar```
    - ```assembly\target\plugins\ru.bmstu.rk9.rao-<version>.jar```

- `mvn deploy` - Запускает сборку и развертывает полученные артифакты в репозитории.

 ```
mvn deploy -Drepository-url=<url-to-repository-root>
```
Параметр `repository-url` задает адрес репозитория, который по умолчанию не задан, поэтому является обязательным при запуске сборки с развертыванием.

- `-Pdebug` - Добавляет в сборку jar'ники с исходниками, которые при необходимости отладки можно использовать в `eclipse` через `attach source` 
    - ```assembly\target\plugins\ru.bmstu.rk9.rao.lib-<version>-sources.jar```
    - ```assembly\target\plugins\ru.bmstu.rk9.rao.ui-<version>-sources.jar```
    - ```assembly\target\plugins\ru.bmstu.rk9.rao-<version>-sources.jar```

## Автосборка на Дженкинсе
### Только джарники
```
export MAVEN_OPTS="-Xmx512M"
mvn initialize -N -Pset-git-version
mvn clean deploy -Drepository-url=file:///home/rdo/nexus/rdo-work/nexus/storage/raox-m2/

```
### Архив с Эклипсом
Cобирается в [aurusov/raox-deploy](https://github.com/aurusov/raox-deploy)
```
export MAVEN_OPTS="-Xmx512M"
cd assembly
mvn initialize -N -Pset-raox-version
mvn clean package -Declipse-path=../../../../eclipses/eclipse-dsl-mars-1-linux-gtk-x64 -Dtarget-os=linux -Dtarget-bitness=x64
```
## Продвижение версии
Продвижение версии можно посмотреть на [gitflow.md](/gitflow.md) в разделе ```release/version```
