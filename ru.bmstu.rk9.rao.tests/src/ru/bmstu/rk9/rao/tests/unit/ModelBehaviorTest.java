package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import org.junit.Test;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator.SimulationStopCode;

public class ModelBehaviorTest {
    static Path repository() { return Paths.get(System.getProperty("raox.repository", "..")).toAbsolutePath().normalize(); }
    static String read(Path file) throws Exception { return new String(Files.readAllBytes(file), StandardCharsets.UTF_8).replace("\r\n", "\n"); }

    @Test public void minimalModelCompilesAndStopsWithoutEvents() throws Exception {
        try (HeadlessModel model = new HeadlessModel("empty", "")) {
            model.compile();
            assertEquals(SimulationStopCode.NO_MORE_EVENTS, model.run(false));
            assertEquals(0.0, CurrentSimulator.getTime(), 0.0);
            assertEquals(3, CurrentSimulator.getDatabase().getAllEntries().size());
        }
    }

    @Test public void utf8ResourcesEventsAndResultsCompileAndExecute() throws Exception {
        Path file = repository().resolve("ru.bmstu.rk9.rao.tests/models/русская_модель.rao");
        try (HeadlessModel model = new HeadlessModel("русская_модель", read(file))) {
            model.compile();
            assertEquals(SimulationStopCode.TERMINATE_CONDITION, model.run(true));
            assertEquals(3.0, CurrentSimulator.getTime(), 0.0);
            assertTrue(model.trace(), model.trace().contains("Событие[2]"));
            assertTrue(model.results(), model.results().contains("Last value: 3"));
        }
    }

    @Test public void syntaxAndTypeErrorsAreRejected() throws Exception {
        for (String source : new String[] {"type Broken { int", "constant x = @", "constant x = missingName", "type T { int n } resource r = T.create(\"text\")"}) {
            try (HeadlessModel model = new HeadlessModel("invalid", source)) {
                assertFalse("Accepted invalid input: " + source, model.errors().isEmpty());
            }
        }
    }

    @Test public void decisionPointsAndResultsFollowSourceOrder() throws Exception {
        String source = "type T { int value }\nresource r = T.create(0)\n"
                + "rule First() { relevant x = r.onlyif[value == 0] def execute() { x.value = 1 } }\n"
                + "rule Second() { relevant x = r.onlyif[value == 0] def execute() { x.value = 2 } }\n"
                + "logic Z { activity a = new Activity(First.create()) }\n"
                + "logic A { activity a = new Activity(Second.create()) }\n"
                + "result z = Result.create([r.value], new LastValueStatistics())\n"
                + "result a = Result.create([r.value], new LastValueStatistics())\n"
                + "def terminateCondition() { return r.value > 0 }";
        try (HeadlessModel model = new HeadlessModel("order", source)) {
            model.compile();
            assertEquals(SimulationStopCode.TERMINATE_CONDITION, model.run(true));
            assertEquals("order.order.z", CurrentSimulator.getResults().get(0).getName());
            assertEquals("order.order.a", CurrentSimulator.getResults().get(1).getName());
            assertTrue(model.results(), model.results().contains("Last value: 1"));
            assertFalse(model.results(), model.results().contains("Last value: 2"));
        }
    }
}
