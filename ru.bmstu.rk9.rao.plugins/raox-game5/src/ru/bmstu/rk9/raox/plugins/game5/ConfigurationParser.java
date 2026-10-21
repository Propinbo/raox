package ru.bmstu.rk9.raox.plugins.game5;

import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

import org.eclipse.core.resources.IFile;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.ui.PlatformUI;
import com.github.cliftonlabs.json_simple.JsonArray;
import com.github.cliftonlabs.json_simple.JsonObject;
import com.github.cliftonlabs.json_simple.Jsoner;
import com.github.cliftonlabs.json_simple.JsonException;

public class ConfigurationParser {
	public static JsonObject parseObject(IFile configIFile) {
		JsonObject object = null;
		try (InputStreamReader reader = new InputStreamReader(configIFile.getContents(), StandardCharsets.UTF_8)) {
			object = (JsonObject) Jsoner.deserialize(reader);
		} catch (IOException | CoreException | JsonException e) {
			e.printStackTrace();
			MessageDialog.openError(PlatformUI.getWorkbench().getActiveWorkbenchWindow().getShell(), "Error",
					"Failed to parse configuration template:\n" + e.getMessage());
			throw new Game5Exception(e);
		}
		return object;
	}

	private static String get2DPosition(int position) {
		final int width = 3;
		final int x = (position - 1) % width + 1;
		final int y = (position - 1) / width + 1;
		return Integer.toString(x) + ", " + Integer.toString(y);
	}

	public static String getResourcesCode(JsonObject object) {
		final JsonArray places = (JsonArray) object.get("places");
		String code = "";

		for (int index = 0; index < places.size(); index++) {
			final String resourceId = Integer.toString(index + 1);
			final String resourceName = index == 5 ? "hole" : "block" + resourceId;
			code += "resource " + resourceName + " = Block.create(" + resourceId + ", new Point("
					+ get2DPosition(Integer.valueOf((String) places.get(index))) + "))";
			if (index != places.size() - 1)
				code += "\n";
		}

		return code;
	}

	public static String getSearchCode(JsonObject object) {
		String costRight = object.get("costRight").toString();
		String computeRight = object.get("computeRight").toString().toUpperCase();

		String costLeft = object.get("costLeft").toString();
		String computeLeft = object.get("computeLeft").toString().toUpperCase();

		String costUp = object.get("costUp").toString();
		String computeUp = object.get("computeUp").toString().toUpperCase();

		String costDown = object.get("costDown").toString();
		String computeDown = object.get("computeDown").toString().toUpperCase();

		String code = "";

		code += "search Game5 {\n";
		code += "\t" + "edge right = new Edge(Move.create(HolePosition.RIGHT), " + costRight + ", ApplyOrder."
				+ computeRight + ")\n";
		code += "\t" + "edge left = new Edge(Move.create(HolePosition.LEFT), " + costLeft + ", ApplyOrder."
				+ computeLeft + ")\n";
		code += "\t" + "edge up = new Edge(Move.create(HolePosition.UP), " + costUp + ", ApplyOrder." + computeUp
				+ ")\n";
		code += "\t" + "edge down = new Edge(Move.create(HolePosition.DOWN), " + costDown + ", ApplyOrder."
				+ computeDown + ")\n";
		code += "\n";
		code += "\t" + "def init() {\n";
		code += "\t\t" + "startCondition = [Block.all.exists[index != getPositionIndex(position)]]\n";
		code += "\t\t" + "terminateCondition = [Block.all.forall[index == getPositionIndex(position)]]\n";
		code += "\t\t" + "compareTops = " + object.get("compare") + "\n";
		code += "\t\t" + "heuristic = [(" + object.get("heuristic") + ") as double]\n";
		code += "\t" + "}\n";
		code += "}";

		return code;
	}
}
