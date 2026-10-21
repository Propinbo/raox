package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.*;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.lang.reflect.Field;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import javax.tools.*;

import com.google.inject.Injector;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.diagnostics.Severity;
import org.eclipse.xtext.generator.IGenerator;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.*;
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver;
import ru.bmstu.rk9.rao.RaoStandaloneSetup;
import ru.bmstu.rk9.rao.lib.database.SerializationObjectsNames;
import ru.bmstu.rk9.rao.lib.modeldata.ModelStructureConstants;
import ru.bmstu.rk9.rao.lib.simulator.*;
import ru.bmstu.rk9.rao.rao.RaoEntity;
import ru.bmstu.rk9.rao.rao.RaoModel;
import ru.bmstu.rk9.rao.ui.execution.ModelInternalsParser;
import ru.bmstu.rk9.rao.ui.results.ResultsParser;
import ru.bmstu.rk9.rao.ui.trace.Tracer;

/** Test adapter for the real Rao generator, javac, metadata parser and simulator.
 * It deliberately does not start an Eclipse workspace or implement a product CLI.
 */
@SuppressWarnings("restriction")
final class HeadlessModel implements AutoCloseable {
    static final Injector INJECTOR = new RaoStandaloneSetup().createInjectorAndDoEMFRegistration();
    final Resource resource;
    final String name;
    private URLClassLoader loader;
    private Path output;

    HeadlessModel(String name, String source) throws Exception {
        this.name = name;
        XtextResourceSet set = INJECTOR.getInstance(XtextResourceSet.class);
        set.setClasspathURIContext(HeadlessModel.class.getClassLoader());
        resource = set.createResource(URI.createPlatformResourceURI("/" + name + "/" + name + ".rao", true));
        resource.load(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)), Collections.singletonMap(XtextResource.OPTION_ENCODING, "UTF-8"));
    }

    List<Issue> errors() {
        List<Issue> errors = new ArrayList<>();
        for (Issue issue : INJECTOR.getInstance(IResourceValidator.class)
                .validate(resource, CheckMode.ALL, CancelIndicator.NullImpl))
            if (issue.getSeverity() == Severity.ERROR) errors.add(issue);
        return errors;
    }

    void compile() throws Exception {
        assertTrue(name + ": " + errors(), errors().isEmpty());
        InMemoryFileSystemAccess fsa = INJECTOR.getInstance(InMemoryFileSystemAccess.class);
        INJECTOR.getInstance(IGenerator.class).doGenerate(resource, fsa);
        output = Files.createTempDirectory("raox-model-");
        List<File> sources = new ArrayList<>();
        for (Map.Entry<String, CharSequence> entry : fsa.getTextFiles().entrySet()) {
            String filename = entry.getKey();
            if (!filename.endsWith(".java")) continue;
            // InMemoryFileSystemAccess prefixes paths with the output configuration.
            filename = filename.substring(filename.indexOf('/') + 1);
            Path file = output.resolve(filename);
            Files.createDirectories(file.getParent());
            Files.write(file, entry.getValue().toString().getBytes(StandardCharsets.UTF_8));
            sources.add(file.toFile());
        }
        assertFalse("No Java generated for " + name, sources.isEmpty());
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        assertNotNull("Tests require a JDK, not a JRE", compiler);
        DiagnosticCollector<JavaFileObject> diagnostics = new DiagnosticCollector<>();
        try (StandardJavaFileManager manager = compiler.getStandardFileManager(diagnostics, Locale.ROOT, StandardCharsets.UTF_8)) {
            List<String> options = Arrays.asList("-encoding", "UTF-8", "-source", "8", "-target", "8",
                    "-classpath", System.getProperty("surefire.test.class.path", System.getProperty("java.class.path")),
                    "-d", output.toString());
            boolean compiled = compiler.getTask(null, manager, diagnostics,
                    options, null, manager.getJavaFileObjectsFromFiles(sources)).call();
            assertTrue(name + ": " + diagnostics.getDiagnostics(), compiled);
        }
        loader = new URLClassLoader(new URL[] {output.toUri().toURL()}, HeadlessModel.class.getClassLoader());
    }

    CurrentSimulator.SimulationStopCode run(boolean trace) throws Exception {
        assertNotNull(loader);
        ModelInternalsParser parser = new ModelInternalsParser(null, null, INJECTOR.getInstance(IBatchTypeResolver.class));
        // Reuse the UI's production metadata parsing without its workspace-only parse().
        Field classLoader = ModelInternalsParser.class.getDeclaredField("classLoader");
        classLoader.setAccessible(true);
        classLoader.set(parser, loader);
        SimulatorPreinitializationInfo pre = parser.getSimulatorPreinitializationInfo();
        pre.modelStructure.put(ModelStructureConstants.NAME, name);
        pre.modelStructure.put(ModelStructureConstants.NUMBER_OF_MODELS, 1);
        RaoModel model = (RaoModel) resource.getContents().get(0);
        parser.parseModel(model, name + "." + name);
        List<String> monitored = new ArrayList<>();
        if (trace) for (RaoEntity entity : model.getObjects()) {
            String fullName = name + "." + name + "." + entity.getName();
            monitored.add(fullName);
            monitored.add(fullName + ".createdResources");
            if (entity instanceof ru.bmstu.rk9.rao.rao.Search) monitored.add(fullName + ".all");
        }
        SerializationObjectsNames.set(monitored);
        CurrentSimulator.set(new Simulator());
        CurrentSimulator.preinitialize(pre);
        SimulatorInitializationInfo init = parser.getSimulatorInitializationInfo();
        parser.postprocessModel();
        CurrentSimulator.initialize(init);
        return CurrentSimulator.run();
    }

    String trace() {
        Tracer tracer = new Tracer(CurrentSimulator.getStaticModelData());
        StringBuilder text = new StringBuilder();
        CurrentSimulator.getDatabase().getAllEntries().forEach(entry -> text.append(tracer.parseSerializedData(entry).content()).append('\n'));
        return text.toString();
    }

    String results() { return ResultsParser.parseAsString(CurrentSimulator.getResults()); }

    @Override public void close() throws Exception {
        if (loader != null) loader.close();
        resource.getResourceSet().getResources().clear();
        if (output != null) {
            try (java.util.stream.Stream<Path> paths = Files.walk(output)) {
                for (Path path : (Iterable<Path>) paths.sorted(Comparator.reverseOrder())::iterator) Files.delete(path);
            }
        }
    }
}
