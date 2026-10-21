package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.*;
import java.util.*;
import org.junit.Test;
import ru.bmstu.rk9.rao.lib.event.*;
import ru.bmstu.rk9.rao.lib.sequence.*;

public class SequenceAndSchedulerTest {
    @Test public void fixedSeedsReproduceEveryDistribution() {
        NumericSequence[] first = sequences(123456789L), second = sequences(123456789L);
        for (int distribution = 0; distribution < first.length; distribution++)
            for (int sample = 0; sample < 100; sample++)
                assertEquals("distribution " + distribution + ", sample " + sample,
                        first[distribution].next(), second[distribution].next(), 0.0);
        assertNotEquals(new Uniform(123456789L, 0, 1).next(), new Uniform(987654321L, 0, 1).next());
    }

    private NumericSequence[] sequences(long seed) {
        return new NumericSequence[] {new Uniform(seed, 0, 1), new Normal(seed, 10, 2),
                new Exponential(seed, 0.5), new Triangular(seed, 0, 10, 4)};
    }

    @Test public void uniformStatisticsMeetAnIndependentTolerance() {
        Uniform uniform = new Uniform(123456789L, 0, 1);
        int count = 100000;
        double sum = 0, sumSquares = 0;
        for (int i = 0; i < count; i++) {
            double x = uniform.next();
            assertTrue(x >= 0 && x < 1);
            sum += x;
            sumSquares += x * x;
        }
        // About five standard errors for the mean; deliberately not a golden sample.
        assertEquals(0.5, sum / count, 0.005);
        assertEquals(1.0 / 12, sumSquares / count - Math.pow(sum / count, 2), 0.002);
    }

    @Test public void schedulerOrdersDifferentTimesAndPreservesAllTies() {
        ProcessTestSuite.initEmptySimulation();
        EventScheduler scheduler = new EventScheduler();
        Event first = event(1), tieA = event(2), tieB = event(2), last = event(3);
        scheduler.pushEvent(last);
        scheduler.pushEvent(tieA);
        scheduler.pushEvent(first);
        scheduler.pushEvent(tieB);
        assertSame(first, scheduler.popEvent());
        Set<Event> ties = new HashSet<>(Arrays.asList(scheduler.popEvent(), scheduler.popEvent()));
        assertEquals(new HashSet<>(Arrays.asList(tieA, tieB)), ties);
        assertSame(last, scheduler.popEvent());
        assertFalse(scheduler.haveEvents());
        // PriorityQueue does not promise FIFO for equal times. Do not freeze its
        // incidental heap ordering as a language compatibility requirement.
    }

    private Event event(double scheduledTime) {
        return new Event() {
            {time = scheduledTime;}
            @Override public String getName() { return "test"; }
            @Override protected void execute() {}
        };
    }
}
