# Recipe Processing Scripts

Scripts used to enrich the bundled `recipes.json` dataset with structured ingredient fields using the DeepSeek API.

## What These Scripts Do

The raw dataset has ingredients as flat strings (e.g. `"2 Tbsp. finely chopped sage"`).
`process_recipes.py` calls DeepSeek to parse each ingredient into four structured fields:

| Field | Example |
|---|---|
| `name` | `"sage"` |
| `amount` | `"2 Tbsp."` |
| `notes` | `"finely chopped"` |
| `basicComponent` | `"sage"` |

It also normalises instruction steps, infers `cuisine` where unambiguous, and derives `additionalInfo` (time, servings, complexity).

## Files

| File | Purpose |
|---|---|
| `process_recipes.py` | Main batch processor — calls DeepSeek API in parallel, checkpoints per batch |
| `verify_recipes.py` | Validates the output JSON for schema correctness against the original |
| `requirements.txt` | Python dependencies (`aiohttp`, `aiofiles`, `tqdm`) |
| `run_tests.sh` | Runs the Xcode unit test suite |

## Setup

```bash
cd scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export DEEPSEEK_API_KEY=your_key_here
```

## Usage

### Full run

```bash
python3 process_recipes.py \
  --input  ../CookSavvy/Support/Assets/recipes.json \
  --output ../CookSavvy/Support/Assets/recipes_processed.json
```

### Resume after partial failure

```bash
python3 process_recipes.py --resume
```

Only batches without a checkpoint file are processed. To force a retry of failed batches, delete their checkpoint files (status `"error"`) from `./checkpoints/` first:

```bash
python3 -c "
import json
from pathlib import Path
for f in Path('checkpoints').glob('batch_*.json'):
    if json.loads(f.read_text()).get('status') == 'error':
        f.unlink(); print(f'Deleted {f.name}')
"
```

### Dry run (first N recipes)

```bash
python3 process_recipes.py --limit 20
```

### Validate output

```bash
python3 verify_recipes.py \
  --original ../CookSavvy/Support/Assets/recipes.json \
  --processed ../CookSavvy/Support/Assets/recipes_processed.json
```

## Key Parameters

| Flag | Default | Notes |
|---|---|---|
| `--batch-size` | 100 | Recipes per API call |
| `--concurrency` | 50 | Parallel API workers |
| `--model` | `deepseek-v4-flash` | DeepSeek model ID |
| `--resume` | off | Skip existing checkpoints |

## Deploying the Result

After a successful run, replace `recipes.json` and update the bundled ZIP archive:

```bash
cp recipes_processed.json ../CookSavvy/Support/Assets/recipes.json
cd ../CookSavvy/Support/Assets
zip -u food-ingredients-and-recipe-dataset-with-images-json.zip recipes.json
```

The `Ingredient` Swift model (`Models/Ingredient.swift`) decodes all four fields automatically via `CodingKeys`.

## Model / API Notes

- **Model**: `deepseek-v4-flash` — supports up to 384K output tokens
- **Thinking**: explicitly disabled (`"thinking": {"type": "disabled"}`) — required for reliable JSON mode
- **JSON mode**: `response_format: {"type": "json_object"}` — enforced structured output
- **Timeout**: 180s per call with 3 retries (2s / 4s / 8s backoff)
- **On failure**: checkpoint stores best-effort partial model output (not originals) plus error list

## Known Data Issues Fixed

- Recipes with Windows-1252 `\x96` / `\x97` characters in titles — normalized before title comparison
- "Ricotta and Cherry Strudel" had a corrupted ingredient (editorial text fragment) — removed from source
