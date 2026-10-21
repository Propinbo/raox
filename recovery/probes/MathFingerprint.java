import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.Arrays;
import org.eclipse.xtext.xbase.lib.Pair;
import ru.bmstu.rk9.rao.lib.sequence.*;

/** Prints compatibility fingerprints; run with the old library before upgrading. */
public class MathFingerprint {
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
    public static void main(String[] args) throws Exception {
        for (String value : fingerprints()) System.out.println(value);
    }
}
