import java.awt.EventQueue;
import java.awt.Frame;
import java.awt.Label;
import java.awt.Panel;
import org.eclipse.swt.SWT;
import org.eclipse.swt.awt.SWT_AWT;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

public final class SwtAwtProbe {
    public static void main(String[] arguments) throws Exception {
        Display display = new Display();
        Shell shell = new Shell(display);
        Frame frame = null;
        try {
            shell.setLayout(new FillLayout());
            Composite embedded = new Composite(shell, SWT.EMBEDDED | SWT.NO_BACKGROUND);
            frame = SWT_AWT.new_Frame(embedded);
            Frame embeddedFrame = frame;
            EventQueue.invokeAndWait(() -> {
                Panel panel = new Panel();
                panel.add(new Label("Rao X: SWT/AWT on Java 21"));
                embeddedFrame.add(panel);
                embeddedFrame.validate();
            });
            shell.setSize(480, 180);
            shell.open();
            long deadline = System.nanoTime() + 2_000_000_000L;
            while (!shell.isDisposed() && System.nanoTime() < deadline) {
                if (!display.readAndDispatch()) Thread.sleep(10);
            }
            EventQueue.invokeAndWait(() -> {
                if (!embeddedFrame.isDisplayable() || embeddedFrame.getComponentCount() != 1) {
                    throw new AssertionError("Embedded AWT frame did not initialize");
                }
            });
            System.out.println("SWT/AWT passed: Java " + System.getProperty("java.version") + ", SWT " + SWT.getVersion());
        } finally {
            if (frame != null) {
                Frame embeddedFrame = frame;
                EventQueue.invokeAndWait(embeddedFrame::dispose);
            }
            shell.dispose();
            display.dispose();
        }
    }
}
