# Rao X: сторонние компоненты

Ревизия: 21 октября 2026 года. Точные пути и SHA-256 бинарников, исходников и
лицензий: `embedded-libraries.lock.json`. Исходный перечень восьми JAR:
`DEPENDENCIES-baseline.csv`. Нынешний перечень: `DEPENDENCIES.csv`.

| Исходный компонент | Решение | Лицензия | Использование и исходники |
| --- | --- | --- | --- |
| Commons Math 3.6 | `org.apache.commons:commons-math3:3.6.1` | Apache-2.0 | MersenneTwister, Erf, PoissonDistribution; sequence/* и process/SelectPath. `licenses/sources/commons-math3-3.6.1-sources.jar` |
| JSON.simple 1.1.1 | `com.github.cliftonlabs:json-simple:4.0.1` | Apache-2.0 | Конфигурация Game5: ConfigurationParser, OrderConfigurator, Game5View, GraphManager. Новый namespace, Jsoner/JsonObject/JsonArray; запись через toJson(). `licenses/sources/json-simple-4.0.1-sources.jar` |
| Gson 2.6.2 | `com.google.code.gson:gson:2.14.0` | Apache-2.0 | Экспорт PlotView в JSON. `licenses/sources/gson-2.14.0-sources.jar` |
| JGraphX 3.3.1.1 | `com.github.vlsi.mxgraph:jgraphx:4.2.2` | BSD-3-Clause | graph/* и граф поиска Game5. Это публикация upstream JGraphX, рекомендованная самим upstream; проект завершил развитие. `licenses/sources/jgraphx-4.2.2-sources.jar` |
| JFreeChart 1.0.19 | `org.jfree:jfreechart:1.5.6` | LGPL-2.1-or-later | plot/*; перенесены RectangleEdge, DatasetUtils, Args. `licenses/sources/jfreechart-1.5.6-sources.jar` |
| JCommon 1.0.23 | Удалён | LGPL-2.1-or-later | Нужные JFreeChart классы теперь входят в JFreeChart 1.5.x |
| JFreeChart experimental 1.0.19 | Удалён | LGPL-2.1-or-later | В коде приложения не использовался |
| JFreeChart SWT 1.0.19 | Исходники `jfree/jfreechart-swt` на `b4762fbe8fc5bae1ae7097f55b099117dee76abe` | LGPL-2.1-or-later | Последний выпущенный SWT 1.0 требует JFreeChart 1.0.19. Версия 1.1.0 ещё не выпущена. Взята фиксированная ревизия исходников, без demos; компилируется вместе с UI. Полный исходный архив: `licenses/sources/jfreechart-swt-b4762fb.zip` |
| Новый SWTGraphics2D | `org.jfree:swtgraphics2d:1.1.0` | LGPL-2.1-or-later | SWTGraphics2D/SWTUtils для SWT-адаптера. SWT берётся из единой target platform, старый SWT из Maven POM не включается. `licenses/sources/swtgraphics2d-1.1.0-sources.jar` |

Apache-2.0: `licenses/Apache-2.0.txt`; BSD: `licenses/jgraphx-LICENSE.txt`;
LGPL: `licenses/LGPL-2.1.txt`. Copyright и исходные notices сохранены в исходниках;
Commons Math LICENSE/NOTICE отдельно включены в `licenses/`. Исходники LGPL
поставляются в дистрибутиве, их можно изменять и пересобирать; код SWT-адаптера
находится в `ru.bmstu.rk9.rao.ui/thirdparty/jfreechart-swt/src`.

## Платформа и встроенные копии

Eclipse/Xtext/EMF/Guice и их транзитивные библиотеки устанавливаются из локального
p2-репозитория. Их исходные about.html, about_files, META-INF/LICENSE/NOTICE
сохраняются внутри каждого bundle. Источники платформы, точные версии и хеши
зафиксированы в `platform/`; полная инвентаризация фактических JAR, включая вложенные
библиотеки и Maven-метаданные затенённых копий, создаётся `Export-DependencyAudit.py`.
Пакет JDK содержит неизменённый каталог `jre/legal` и исходники `jre/lib/src.zip`.

`org.apache.log4j` в Eclipse 2025-09 — **reload4j 1.2.26**, координаты
`ch.qos.reload4j:reload4j:1.2.26`, Apache-2.0. Сгенерированный Xtext-код и MWE2
используют API Log4j 1; manifest ограничивает импорт версией не ниже 1.2.26.
Это совместимый провайдер из зафиксированной платформы. Последующий перенос
генератора на другой logging API требует согласованного обновления Xtext/MWE2.

В runtime есть четыре изменённых класса JSON.org с `@version 2014-05-03`,
перенесённые в `ru.bmstu.rk9.rao.lib.json`. Они используют LinkedHashMap для порядка
полей исторических результатов. Сохранены как отдельная копия исходного кода,
с исходной лицензией **JSON** (`licenses/JSON-LICENSE.txt`), содержащей условие
«The Software shall be used for Good, not Evil». Лицензия проекта MIT не заменяет
это условие. Точного Maven-релиза у модифицированной копии нет; нельзя считать
проверку `org.json:json` точной проверкой этой копии. Парсер не ограничивает глубину
вложенности и не предназначен для обработки недоверенного JSON произвольного
размера. Замена должна отдельно сохранить порядок и формат исторических данных.

`lib/thirdparty/AbstractGenerator.java` существует в исходном репозитории без
отдельного copyright/ссылки на первоисточник. Происхождение не установлено;
это явно отмеченная граница ревизии, а не основание приписать ему чужую лицензию.
Реализация сохранена ради совместимости пользовательских Generator/yield.

## Advisory

Запросы к OSV сделаны по точным координатам и версиям; дата и ответы сохранены
в `evidence/stage5-embedded-osv.json`. У Gson 2.6.2 найден
[CVE-2022-25647 / GHSA-4jrv-ppp4-jm57](https://osv.dev/vulnerability/GHSA-4jrv-ppp4-jm57),
исправленный до выбранной версии. JSON-экспорт Rao X не использует Java object
deserialization из advisory, но старая зависимость всё равно заменена.

Отсутствие совпадений в OSV не доказывает отсутствие дефектов. Для модифицированных
исходников и p2-bundle без точных Maven-координат автоматическое сопоставление
неполно; они явно перечислены в отчёте. Известные ограничения встроенного JSON
и прекращение развития JGraphX сохраняются. Для JFreeChart 1.5.4 upstream отдельно
разбирает CVE-2023-52070, CVE-2024-22949 и CVE-2024-23076 в
[release notes](https://github.com/jfree/jfreechart/releases/tag/v1.5.5);
используется 1.5.6, а указанные типы графиков не используются Rao X.

Сторонние библиотеки и их лицензии не покрываются лицензией MIT проекта Rao X.
