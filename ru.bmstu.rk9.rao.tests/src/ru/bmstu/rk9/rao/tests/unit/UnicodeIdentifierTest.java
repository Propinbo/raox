package ru.bmstu.rk9.rao.tests.unit;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import java.io.StringReader;

import org.antlr.runtime.ANTLRStringStream;
import org.antlr.runtime.Lexer;
import org.antlr.runtime.Token;
import org.eclipse.xtext.parser.IParseResult;
import org.eclipse.xtext.parser.IParser;
import org.junit.Test;

import ru.bmstu.rk9.rao.RaoStandaloneSetup;
import ru.bmstu.rk9.rao.parser.antlr.internal.InternalRaoLexer;
import ru.bmstu.rk9.rao.rao.Constant;
import ru.bmstu.rk9.rao.rao.RaoModel;

/** Guards both generated lexers against the old RULE_ANY_OTHER generation failure. */
public class UnicodeIdentifierTest {
    private static final String[] IDENTIFIERS = {
        "Имя_ресурса42", "Δοκιμή", "模型", "café", "a\u0301", "^constant", "\\" + "u0418мя"
    };

    @Test
    public void runtimeLexerRecognizesUnicodeIdentifiers() {
        for (String identifier : IDENTIFIERS) {
            assertIdentifier(new InternalRaoLexer(new ANTLRStringStream(identifier)), identifier,
                    InternalRaoLexer.RULE_ID);
        }
        Lexer lexer = new InternalRaoLexer(new ANTLRStringStream("@"));
        assertEquals(InternalRaoLexer.RULE_ANY_OTHER, lexer.nextToken().getType());
    }

    @Test
    public void contentAssistLexerRecognizesUnicodeIdentifiers() {
        for (String identifier : IDENTIFIERS) {
            assertIdentifier(new ru.bmstu.rk9.rao.ide.contentassist.antlr.internal.InternalRaoLexer(
                    new ANTLRStringStream(identifier)), identifier,
                    ru.bmstu.rk9.rao.ide.contentassist.antlr.internal.InternalRaoLexer.RULE_ID);
        }
    }

    @Test
    public void parserPreservesUnicodeNames() {
        IParser parser = new RaoStandaloneSetup().createInjectorAndDoEMFRegistration().getInstance(IParser.class);
        for (String name : new String[] {"Имя_ресурса42", "Δοκιμή", "模型", "café", "a\u0301"}) {
            IParseResult result = parser.parse(new StringReader("constant " + name + " = 1"));
            assertFalse("Syntax error for " + name, result.hasSyntaxErrors());
            RaoModel model = (RaoModel) result.getRootASTElement();
            assertEquals(1, model.getObjects().size());
            assertEquals(name, ((Constant) model.getObjects().get(0)).getName());
        }
    }

    private static void assertIdentifier(Lexer lexer, String input, int tokenType) {
        Token token = lexer.nextToken();
        assertEquals(input, tokenType, token.getType());
        assertEquals(input, token.getText());
        assertEquals(input, Token.EOF, lexer.nextToken().getType());
    }
}
