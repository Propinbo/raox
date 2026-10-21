# Rao X

Rao X — среда дискретно-событийного моделирования на Eclipse и Xtext/Xbase.
Поддерживаемая и проверенная цель — Windows x64 / Java 21.

Начните с [Windows quick start](docs/user_guide/quick_start.html): инструменты,
сборка, установка, первая модель и ожидаемый результат.
Откройте [docs/index.html](docs/index.html) с диска для чтения всей HTML-справки без сети.

```powershell
.\recovery\Initialize-Platform.ps1 -IncludeUi
.\recovery\Invoke-PlatformBuild.ps1 -Clean
.\recovery\New-WindowsDistribution.ps1
```

Запускайте команды в PowerShell 7 из корня исходников в ASCII-пути.
Скрипты загружают Temurin **21.0.12.1+1**, Maven **3.9.11**, Eclipse **2025-09**
и RCPTT **2.6.1**; сборка использует Tycho **4.0.13**, Xtext/Xbase/Xtend **2.40.0**.
Первой загрузке нужна сеть. Инструменты и кэш изолированы в `.build`.

Распакуйте `assembly/target/windows-x64/raox-3.9.0-windows-x86_64.zip` целиком
в доступный для записи каталог и запустите `raox/eclipse.exe` с новым workspace.
Java включена в архив. Плагины отдельно: `assembly/target/raox-3.9.0.zip`,
полный p2: `raox.repository/target/raox.repository-3.9.0.zip`.

- [Команды сборки, упаковки, UI и диагностики](build-with-maven.md).
- [Архитектура, генерация, отладка, форматы и выпуск](docs/development.md).
- [Roadmap](recovery/ROADMAP.md), [точка передачи](recovery/STATE.md), [отчёт этапа 6](recovery/STAGE6.md).
- [Зависимости, лицензии и ограничения](recovery/THIRD-PARTY.md).
- [Историческая установка Java 8 / Neon](docs/history/README-legacy.md)
  и [старые Maven/Jenkins-команды](docs/history/build-legacy.md).

Контроль поведения: 38 JUnit (включая 17 исторических моделей и шесть полных
HTML-примеров), 43 RCPTT (включая quick start в новом workspace), проверка CSV/JSON,
native launcher и SWT/AWT. [Свидетельства документации](recovery/STAGE6.md).

[Windows CI](.github/workflows/legacy-build.yml) настроен на холодную и offline-сборку,
упаковку и дополнительный UI-прогон. Последний подтверждённый удалённый запуск —
[этап 3, JDK 8](https://github.com/Propinbo/raox/actions/runs/39588936426).
Исходники этапов 4–6 находятся в ветке `codex/stage3-reproducibility` fork.
Ветка по умолчанию `release/current` содержит прежнюю версию. Получить восстановленную:

```powershell
git clone --branch codex/stage3-reproducibility --single-branch https://github.com/Propinbo/raox.git
```

Точка передачи, локальные результаты проверок и статус удалённого CI — в STATE.
