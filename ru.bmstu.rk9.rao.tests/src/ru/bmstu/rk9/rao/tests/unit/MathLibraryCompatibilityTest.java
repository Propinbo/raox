package ru.bmstu.rk9.rao.tests.unit;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.Arrays;
import org.eclipse.xtext.xbase.lib.Pair;
import ru.bmstu.rk9.rao.lib.sequence.*;

/** Prints compatibility fingerprints; run with the old library before upgrading. */
public class MathLibraryCompatibilityTest {
    public static String[] fingerprints() throws Exception {
        long seed = 123456789L;
        NumericSequence[] sequences = {
            new Uniform(seed, 0, 1), new Normal(seed, 10, 2),
            new Exponential(seed, 0.5), new Triangular(seed, 0, 10, 4),
            new Poisson(seed, 4), new Poisson(seed, 80),
            new ContinuousHistogram(seed, Arrays.asList(Pair.of(1, 1), Pair.of(4, 2)))
        };
        String[] result = new String[sequences.length + 1];
        for (int n = 0; n < sequences.length; n++) {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (int i = 0; i < 1000; i++)
                digest.update(ByteBuffer.allocate(8).putDouble(sequences[n].next()).array());
            result[n] = java.util.HexFormat.of().formatHex(digest.digest());
        }
        DiscreteHistogram<Integer> histogram = new DiscreteHistogram<>(seed,
                Arrays.asList(Pair.of(1, 1), Pair.of(4, 2)));
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        for (int i = 0; i < 1000; i++)
            digest.update(ByteBuffer.allocate(4).putInt(histogram.next()).array());
        result[sequences.length] = java.util.HexFormat.of().formatHex(digest.digest());
        return result;
    }
    @org.junit.Test public void samplesMatchCommonsMath36Baseline() throws Exception {
        org.junit.Assert.assertArrayEquals(new String[] {
            "81b15231182d1a64e76336b70838d98a8ea3dcb8067350477a01969aecf2b4f4",
            "8a706d50db25363072e186e8fad848d08ea0ab63a37a19cafd944694ff56a416",
            "1dc1cc1906fd5adff85bb6d3824947b4c6a0a8d15f177b491d46189434db5c32",
            "b6cf3909d641687739228c240e906cfee83c532b44a2c69f9b1a4090ac8be2ec",
            "e8bc75338967ae5fce640fe3f1cdafd7d3bf900d90fa17e65f18ca0d0b3f26d4",
            "59b87e54d81285348550d09ed8b0b4d79ee12a34839de08ca8d28064ea9a7c7d",
            "374f710b072f646755425c2dec01dd240d922defe20a5e27ed727d9853cf7d07",
            "0a3aa09bc4e58f69f59e5be8ec041f17909e07181493fc44ae7844f359ed0bed"
        }, fingerprints());
    }
}
