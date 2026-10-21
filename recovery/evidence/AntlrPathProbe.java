import org.antlr.Tool;
import org.antlr.tool.Grammar;
public class AntlrPathProbe {
    static class PathTool extends Tool {
        Grammar root;
        PathTool(String[] args) { super(args); }
        public Grammar getRootGrammar(String file) throws java.io.IOException { return root = super.getRootGrammar(file); }
    }
    public static void main(String[] args) throws Exception {
        String grammar = new String(java.util.Base64.getDecoder().decode(args[0]), "UTF-8");
        PathTool tool = new PathTool(new String[] {"-Xconversiontimeout", "0", "-Xsavelexer", "-o", args[1], grammar});
        tool.process();
        java.nio.file.Files.write(java.nio.file.Paths.get(args[1], "implicit-lexer.g"), tool.root.getLexerGrammar().getBytes("UTF-8"));
        System.exit(tool.getNumErrors() == 0 ? 0 : 1);
    }
}