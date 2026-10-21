package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.*;
import java.nio.file.*;
import java.util.regex.*;
import org.junit.Test;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator;
import ru.bmstu.rk9.rao.lib.simulator.CurrentSimulator.SimulationStopCode;

/** Compile the actual complete HTML examples, not a separate copy of their source. */
public class DocumentationExamplesTest {
    private static String source(String path, String id) throws Exception {
        String html = ModelBehaviorTest.read(ModelBehaviorTest.repository().resolve(path));
        Matcher block = Pattern.compile("<code class=\"rao\" id=\"" + id + "\">(.*?)</code>", Pattern.DOTALL).matcher(html);
        assertTrue("Missing documented model: " + path, block.find());
        return block.group(1).replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&amp;", "&");
    }

    private static void run(String path, String id, String name, double time, String... results) throws Exception {
        try (HeadlessModel model = new HeadlessModel(name, source(path, id))) {
            model.compile();
            assertEquals(SimulationStopCode.TERMINATE_CONDITION, model.run(true));
            assertEquals(time, CurrentSimulator.getTime(), 1e-10);
            for (String result : results) assertTrue(model.results(), model.results().contains(result));
            // Preserve exact public trace and numeric result text from each tutorial.
            String html = ModelBehaviorTest.read(ModelBehaviorTest.repository().resolve(path));
            for (String output : new String[] {"expected-trace", "expected-results"}) {
                Matcher block = Pattern.compile("<code class=\"[^\"]+\" id=\"" + output + "\">(.*?)</code>", Pattern.DOTALL).matcher(html);
                if (block.find()) {
                    String expected = block.group(1).strip().replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&");
                    String actual = output.equals("expected-trace") ? model.trace().strip() : model.results().strip().replace("\r\n", "\n");
                    assertEquals(path + " " + output, expected, actual);
                }
            }
        }
    }

    @Test(timeout=120000) public void quickStart() throws Exception {
        run("docs/user_guide/quick_start.html", "quickstart-source", "hello", 3.0, "Last value: 4");
    }

    @Test(timeout=120000) public void callCountTutorial() throws Exception {
        run("docs/tutorial/call_center_call_count.html", "model-source", "call_center", 486.85470956869307, "Last value: 11.0");
    }

    @Test(timeout=120000) public void singleOperatorTutorial() throws Exception {
        run("docs/tutorial/call_center_single_operator.html", "model-source", "test", 486.85470956869307, "Last value: 10.0", "Last value: 1.0");
    }

    @Test(timeout=120000) public void loggingExample() throws Exception {
        run("docs/debug/logger.html", "model-source", "logging", 486.85470956869307);
    }

    @Test(timeout=120000) public void animationExamplesCompile() throws Exception {
        // Sprite images and interactive input belong to the external example project.
        // Compile the exact guide code without starting an SWT display or a million events.
        for (String id : new String[] {"vector-source", "sprites-source"}) {
            try (HeadlessModel model = new HeadlessModel("animation", source("docs/reference/animation.html", id))) {
                model.compile();
            }
        }
    }
}
