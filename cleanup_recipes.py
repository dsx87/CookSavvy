import json
import pathlib

FIELDS_TO_REMOVE = {"tagline", "userRating", "apiRating", "author", "isUserCreated", "emoji"}
JSON_PATH = pathlib.Path(__file__).parent / "CookSavvy/Support/Assets/recipes.json"

with open(JSON_PATH) as f:
    recipes = json.load(f)

for recipe in recipes:
    for field in FIELDS_TO_REMOVE:
        recipe.pop(field, None)
    recipe["instructions"] = [step["text"] for step in recipe["instructions"]]

with open(JSON_PATH, "w") as f:
    json.dump(recipes, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"Cleaned {len(recipes)} recipes → {JSON_PATH}")
