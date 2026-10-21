package ru.bmstu.rk9.raox.plugins.game5;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.HashSet;

import com.github.cliftonlabs.json_simple.JsonArray;
import com.github.cliftonlabs.json_simple.JsonObject;
import com.github.cliftonlabs.json_simple.Jsoner;
import com.github.cliftonlabs.json_simple.JsonException;

public class OrderConfigurator {
	private static final int tilesCountX = 3;
	private static final int tilesCountY = 2;

	@SuppressWarnings("unchecked")
	public static void setInOrder(JsonObject object) throws IOException, JsonException {
		try (InputStream inputStream = Game5View.class.getClassLoader()
				.getResourceAsStream(Game5ProjectConfigurator.configTemplatePath);
				InputStreamReader reader = new InputStreamReader(inputStream, StandardCharsets.UTF_8)) {
			JsonObject templateObject = (JsonObject) Jsoner.deserialize(reader);
			object.put("places", templateObject.get("places"));
		}
	}

	public static JsonArray shuffle(JsonArray places, String solvable) {
		if (solvable.equals("all")) {
			Collections.shuffle(places);
			return places;
		}
		JsonArray order = inverseOrderPlaces(places);
		do {
			Collections.shuffle(order);
		} while (!solvable.equals(String.valueOf(isSolvable(tilesCountX, tilesCountY, order))));
		return inverseOrderPlaces(order);
	}

	private static boolean isSolvable(int tilesCountX, int tilesCountY, JsonArray order) {

		final int freePlaceRow = order.indexOf(String.valueOf(tilesCountX * tilesCountY)) / tilesCountX + 1;
		int sum = 0;
		for (int i = 0; i < tilesCountX * tilesCountY; i++) {
			int tileIndex = Integer.valueOf(order.get(i).toString());
			if (tileIndex == tilesCountX * tilesCountY)
				continue;
			for (int j = i + 1; j < tilesCountX * tilesCountY; j++) {
				if (tileIndex > Integer.valueOf(order.get(j).toString()))
					sum++;
			}
		}

		if (tilesCountX % 2 != 0) {
			return sum % 2 == 0;
		} else {
			return (tilesCountY % 2) == ((sum + freePlaceRow) % 2);
		}
		// См. Перельман. Живая математика.
	}

	public static String convertPlacesToString(JsonArray places) {
		String order = Integer.toString(places.indexOf(String.valueOf(1)) + 1);
		for (int i = 1; i < places.size(); i++) {
			order = order + " " + Integer.toString(places.indexOf(String.valueOf(i + 1)) + 1);
		}
		return order;
	}

	@SuppressWarnings("unchecked")
	public static JsonArray convertStringToPlaces(String order) {
		String[] orderList = order.split(" ");
		JsonArray orderArray = new JsonArray();
		if (!orderIsValid(orderList)) {
			return null;
		}
		for (int i = 0; i < orderList.length; i++) {
			orderArray.add(orderList[i]);
		}
		return inverseOrderPlaces(orderArray);
	}

	@SuppressWarnings("unchecked")
	public static JsonArray inverseOrderPlaces(JsonArray position) {
		JsonArray inversePosition = new JsonArray();
		for (int i = 1; i < position.size() + 1; i++)
			inversePosition.add(String.valueOf(position.indexOf(String.valueOf(i)) + 1));
		return inversePosition;
	}

	private static boolean orderIsValid(String[] orderList) {
		HashSet<Integer> standartOrder = new HashSet<>();

		for (int i = 0; i < tilesCountX * tilesCountY; i++) {
			standartOrder.add(i + 1);
		}
		for (int i = 0; i < orderList.length; i++) {
			try {
				if (!standartOrder.remove(Integer.valueOf(orderList[i]))) {
					return false;
				}
			} catch (NumberFormatException e) {
				return false;
			}
		}
		return standartOrder.size() == 0;
	}
}
