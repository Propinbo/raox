# Rao X

## Building the legacy plugins

The Windows x64 build uses pinned Temurin 8u504-b01, Maven 3.3.9 and
[an exact Mars / Xtext 2.9.2 target](raox.target/raox.target.target).
Run from PowerShell in the source checkout:

```powershell
.\recovery\Initialize-Toolchains.ps1
.\recovery\Invoke-LegacyBuild.ps1 -Clean -Goal verify
```

JDK downloads and the Maven Wrapper distribution are verified with SHA-256.
See [the build instructions](build-with-maven.md) and [stage 3 evidence](recovery/STAGE3.md).
A clean build creates
`assembly/target/raox-3.9.0.zip` and runs 32 JUnit checks, including compilation and simulation
of all 17 historical RCPTT models with exact trace/result comparisons.
See [the behavior verification report](recovery/STAGE2.md) for the separate RCPTT UI command.
The [GitHub Actions workflow](.github/workflows/legacy-build.yml) starts each build with
an empty Maven/p2 cache and retains the ZIP, logs and JUnit reports. Its manual
`run_ui` option runs the 42 RCPTT checks in a separate job once the workflow is in the default branch.
The [verified Windows Server 2022 run](https://github.com/Propinbo/raox/actions/runs/39588936426)
passed both the empty-cache build and an offline rebuild, with 32 JUnit checks each.
All 858 compiled classes match the local build that passed 42 RCPTT checks.
The recovery branch is in [the Propinbo fork](https://github.com/Propinbo/raox/tree/codex/stage3-reproducibility).
Use an ASCII path for the source checkout; spaces are supported. The legacy ANTLR generator
cannot process non-ASCII source paths. Unicode identifiers in models are tested separately.

The manual Eclipse setup below is historical.

## Summary
<img src=docs/raox.png><img>
This project is an implementation of RAO modelling language in [Eclipse](https://eclipse.org), using [Xbase](https://wiki.eclipse.org/Xbase).
* [About RAO modelling language (rus)](http://raox.ru/docs/reference/base_types_and_functions.html)

## Preparing
 * Install [Ubuntu Desktop](http://www.ubuntu.com/download/desktop/) or any other [linux distribution](http://www.linux.com/directory/Distributions/desktop)
 * Install Java 8

   **IMPORTANT** Latest version of openjdk at the moment of writing this (openjdk-8-jdk 8u66) crushes when using`SWT_AWT` bridge.
   Oracle jdk distributions should be used instead. For debian-based linux distributions:
```bash
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install oracle-java8-installer
```
   Check java version:
```bash
java -version
```
   If output is different than (except version numbers):
```bash
java version "1.8.0_66"
Java(TM) SE Runtime Environment (build 1.8.0_66-b17)
Java HotSpot(TM) 64-Bit Server VM (build 25.66-b17, mixed mode)
```
   set it manually
```bash
sudo update-alternatives --config java
```
 * Download [Eclipse IDE for Java and DSL Developers](http://www.eclipse.org/downloads/packages/eclipse-ide-java-and-dsl-developers/neonr)
```bash
cd ~/Downloads
gunzip -c eclipse-dsl-neon-R-linux-gtk-x86_64.tar.gz  | tar xvf -
cd eclipse
./eclipse
```
 * Git clone `raox` repository
```bash
ssh-add ~/.ssh/github.openssh.private.key
git clone git@github.com:aurusov/raox.git
```
## Installing
### Setting up the workspace for Eclipse
* `File` `>` `Import` `>` `General` `>` `Existing Projects into Workspace``>` `Select root directory` `>` `/home/USERNAME/git/raox` `>` `Finish`
* Wait for the workspace to build and get tons of errors
* `ru.bmstu.rk9.rao/src/ru.bmstu.rk9.rao/Rao.xtext` `>` `Run As` `>` `Generate Xtext Artifacts` `>` `Proceed`
* `*ATTENTION* It is recommended to use the ANTLR 3...` press `y`
```
0    [main] INFO  lipse.emf.mwe.utils.StandaloneSetup  - Registering platform uri '/home/drobus/git/raox'
637  [main] INFO  lipse.emf.mwe.utils.StandaloneSetup  - Adding generated EPackage 'org.eclipse.xtext.common.types.TypesPackage'
644  [main] INFO  ipse.emf.mwe.utils.DirectoryCleaner  - Cleaning /home/drobus/git/raox/ru.bmstu.rk9.rao/../ru.bmstu.rk9.rao/src-gen
652  [main] INFO  ipse.emf.mwe.utils.DirectoryCleaner  - Cleaning /home/drobus/git/raox/ru.bmstu.rk9.rao/../ru.bmstu.rk9.rao/model
652  [main] INFO  ipse.emf.mwe.utils.DirectoryCleaner  - Cleaning /home/drobus/git/raox/ru.bmstu.rk9.rao/../ru.bmstu.rk9.rao.ui/src-gen
653  [main] INFO  ipse.emf.mwe.utils.DirectoryCleaner  - Cleaning /home/drobus/git/raox/ru.bmstu.rk9.rao/../ru.bmstu.rk9.rao.tests/src-gen
5720 [main] INFO  clipse.emf.mwe.utils.GenModelHelper  - Registered GenModel 'http://www.bmstu.ru/rk9/rao/Rao' from 'platform:/resource/ru.bmstu.rk9.rao/model/generated/Rao.genmodel'
27489 [main] INFO  text.generator.junit.Junit4Fragment  - generating Junit4 Test support classes
27496 [main] INFO  text.generator.junit.Junit4Fragment  - generating Compare Framework infrastructure
27550 [main] INFO  .emf.mwe2.runtime.workflow.Workflow  - Done.
```
> The workflow disables ANTLR's time limit for DFA analysis, and the build checks Unicode
> identifiers in both generated lexers and the parser. If generation fails, preserve the
> first error and fix its cause; repeated generation is not a recovery procedure.

* `Run` `>` `Run Configurations...` `>` `Eclipse Application` `>` `New` `>` `Name` `=`
 * `raox`
* `Run`

## Running
* `Window` `>` `Open Perspective` `>` `Other...` `>` `Rao`
* `File` `>` `New` `>` `Project...` `>` `Rao` > `Rao Project` `>` `Next>` `>` `Project name:` `>`
 * set project name<br>
 * choose model template<br>
* `Finish`
* [Models examples](https://github.com/aurusov/raox-models)
