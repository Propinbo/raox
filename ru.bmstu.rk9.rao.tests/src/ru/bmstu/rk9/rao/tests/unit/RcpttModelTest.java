package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.*;
import java.nio.file.*;
import java.util.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator.SimulationStopCode;

/** The original RCPTT fixtures, without UI automation. Never rewrites the etalons. */
@RunWith(Parameterized.class)
public class RcpttModelTest {
    @Parameterized.Parameters(name="{0}") public static Collection<Object[]> models() throws Exception {
        List<Object[]> models = new ArrayList<>();
        try (DirectoryStream<Path> directories = Files.newDirectoryStream(ModelBehaviorTest.repository().resolve("ru.bmstu.rk9.rao.rcptt/tests"), "model_*")) {
            for (Path directory : directories) if (Files.isDirectory(directory)) models.add(new Object[] {directory.getFileName().toString().substring(6)});
        }
        models.sort(Comparator.comparing(row -> (String) row[0]));
        assertEquals("Every RCPTT model must be represented", 17, models.size());
        return models;
    }

    private final String name;
    public RcpttModelTest(String name) { this.name = name; }

    @Test(timeout=120000) public void generatedModelMatchesTraceAndResults() throws Exception {
        Path repo = ModelBehaviorTest.repository();
        Path directory = repo.resolve("ru.bmstu.rk9.rao.rcptt/tests/model_" + name);
        Path source = directory.resolve(name + ".rao.template");
        if (!Files.exists(source)) source = repo.resolve("ru.bmstu.rk9.rao.ui/model_templates/" + name + ".rao.template");
        try (HeadlessModel model = new HeadlessModel(name, ModelBehaviorTest.read(source))) {
            model.compile();
            SimulationStopCode code = model.run(true);
            assertTrue("Unexpected stop: " + code, code == SimulationStopCode.TERMINATE_CONDITION || code == SimulationStopCode.NO_MORE_EVENTS);
            String trace = model.trace();
            assertEquals(name, ModelBehaviorTest.read(directory.resolve(name + ".trc.etalon")), trace);
            Path results = directory.resolve(name + ".res.etalon");
            if (Files.exists(results)) assertEquals(ModelBehaviorTest.read(results), model.results().replace("\r\n", "\n") + "\n");
            double time = CurrentSimulator.getTime();
            // Reload generated classes: sequence seeds and static resource state must restart.
            if (name.endsWith("_sequence")) {
                try (HeadlessModel repeated = new HeadlessModel(name, ModelBehaviorTest.read(source))) {
                    repeated.compile();
                    assertEquals(code, repeated.run(true));
                    assertEquals(time, CurrentSimulator.getTime(), 0.0);
                    assertEquals("Seed reproducibility", trace, repeated.trace());
                }
            }
        }
    }
}
