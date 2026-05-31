#!/usr/bin/env python3
"""
Batch-parallel DeepSeek processor for recipes.json.

Reads the bundled recipe dataset, parses each ingredient string into
name / rawAmount / notes fields, normalises instruction steps, and
infers cuisine where obvious. Outputs a new JSON file ready for review.

Usage:
    python process_recipes.py [OPTIONS]

    --input PATH          Source JSON (default: ../CookSavvy/Support/Assets/recipes.json)
    --output PATH         Output JSON (default: ../CookSavvy/Support/Assets/recipes_processed.json)
    --checkpoint-dir DIR  Per-batch checkpoint dir (default: ./checkpoints)
    --batch-size N        Recipes per API call (default: 50)
    --concurrency N       Parallel workers (default: 15)
    --limit N             Only process first N recipes — for dry runs
    --model NAME          DeepSeek model ID (default: deepseek-v4-flash)
    --resume              Skip already-checkpointed batches

Env: DEEPSEEK_API_KEY (required)
"""

import argparse
import asyncio
import json
import math
import os
import sys
import time
import unicodedata
from pathlib import Path

import aiofiles
import aiohttp
from tqdm import tqdm

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

# Hard per-call deadline (seconds). If the API call + all retries exceed this,
# the batch is abandoned and stored as-is. This prevents silent hangs.
CALL_HARD_TIMEOUT = 180

# Input / output pricing per million tokens
INPUT_COST_PER_M  = 0.14
OUTPUT_COST_PER_M = 0.28

SYSTEM_PROMPT = """You are a recipe data formatter that outputs JSON. Reformat only — never invent or add content.

RULES (follow exactly):
1. Return JSON: {"recipes": [...]} — the array must have the SAME LENGTH as input, in order.
2. For each recipe, echo "title" verbatim (character-for-character).
3. INGREDIENTS — process each ingredient string into one entry per distinct food item.
   Each entry must have four fields: name, amount, notes, basicComponent.

   "name" — descriptive ingredient name, stripped of quantity and pure prep actions only:
     - Remove amounts and units
     - Remove pure prep verbs: chopped, minced, diced, sliced, grated, shredded,
       melted, softened, divided, torn, peeled, trimmed
     - KEEP all words that identify what the ingredient IS: unsalted, kosher, extra-virgin,
       smoked, ground, crushed, dried, whole, full-fat, extra-sharp, evaporated, etc.

   "amount" — the numeric value + unit ONLY:
     - Include: number (with fractions ½ ¾ ¼ etc.) + unit (tsp., tbsp., cup, lb., oz., pinch, etc.)
     - Strip size qualifiers (small, medium, large) → move to notes
     - Strip ALL parenthetical text "(about…)", "(such as…)" → move to notes
     - "" if no numeric amount

   "notes" — prep actions stripped from name, size qualifiers, parenthetical details, and
     any other context ("divided", "plus more", "room temperature", "about 3 lb. total"):
     - "" if nothing to add

   "basicComponent" — the core food noun only, for ingredient matching and substitution:
     - Strip ALL adjectives: unsalted/salted, kosher/sea, extra-virgin, smoked, dried, ground,
       crushed, evaporated, whole, full-fat, low-fat, extra-sharp, unbleached, fresh
     - Keep only the essential food noun(s) — usually 1–3 words
     - For compound nouns keep both meaningful words: "olive oil", "cream cheese",
       "red pepper flakes", "chicken broth", "black pepper", "apple cider vinegar"
     - Different varieties that map to the same base food should share a basicComponent:
       "evaporated milk" → "milk", "whole milk" → "milk", "chicken breast" → "chicken"

   COMBINED INGREDIENTS — when one ingredient string lists two or more distinct foods
   joined by "and", ", ", "or" (e.g. "Kosher salt, freshly ground pepper"):
     - If ALL components are already individually listed elsewhere in this recipe's ingredient
       list, DROP the combined entry entirely — output nothing for it. This reduces the array length.
     - If NONE of the components are already listed, split into a SEPARATE entry per component.
       This increases the array length.
     - If SOME components are already listed, output only the unlisted component(s).
     - Never output "salt and pepper" as a single entry.

4. INSTRUCTIONS — rewrite as clear imperative steps:
   - Split long multi-action paragraphs into separate steps
   - Remove "Cook's Notes" / "Make-ahead" annotations (they are not cooking steps)
   - Preserve all temperatures, times, and quantities
5. CUISINE — infer only when unambiguous from title+ingredients (e.g. "Chicken Tikka Masala" → "Indian"). Use null if unsure.
6. ADDITIONAL INFO — derive from the title and instructions. Output a flat JSON object:
   - "time": total estimated time (prep + cook + passive). Format: "X min", "X hr", or "X hr Y min".
     Add up all time steps mentioned (marinating, chilling, resting, etc.). Omit if truly unclear.
   - "servings": integer number of servings if mentioned or clearly implied. Omit if unknown.
   - "complexity": always include. "Easy" (≤6 steps, basic technique), "Hard" (many steps,
     advanced technique, special equipment), or "Medium" for everything in between.
   Example output: {"time": "45 min", "servings": 4, "complexity": "Easy"}
   Omit "time" and "servings" if uncertain; "complexity" is always required.
7. Do NOT change: image, source fields.

EXAMPLES:
Input: "2 Tbsp. finely chopped sage"
→ {"name": "sage", "amount": "2 Tbsp.", "notes": "finely chopped", "basicComponent": "sage"}

Input: "1 (3½–4-lb.) whole chicken"
→ {"name": "whole chicken", "amount": "1", "notes": "3½–4-lb.", "basicComponent": "chicken"}

Input: "¼ tsp. ground allspice"
→ {"name": "ground allspice", "amount": "¼ tsp.", "notes": "", "basicComponent": "allspice"}

Input: "Pinch of crushed red pepper flakes"
→ {"name": "crushed red pepper flakes", "amount": "pinch", "notes": "", "basicComponent": "red pepper flakes"}

Input: "6 Tbsp. unsalted butter, melted"
→ {"name": "unsalted butter", "amount": "6 Tbsp.", "notes": "melted", "basicComponent": "butter"}

Input: "2 Tbsp. extra-virgin olive oil"
→ {"name": "extra-virgin olive oil", "amount": "2 Tbsp.", "notes": "", "basicComponent": "olive oil"}

Input: "4 oz. full-fat cream cheese"
→ {"name": "full-fat cream cheese", "amount": "4 oz.", "notes": "", "basicComponent": "cream cheese"}

Input: "1 tsp. smoked paprika"
→ {"name": "smoked paprika", "amount": "1 tsp.", "notes": "", "basicComponent": "paprika"}

Input: "2 small acorn squash (about 3 lb. total)"
→ {"name": "acorn squash", "amount": "2", "notes": "small, about 3 lb. total", "basicComponent": "acorn squash"}

Input: "2 large egg whites"
→ {"name": "egg whites", "amount": "2", "notes": "large", "basicComponent": "egg"}

Input: "½ small red onion, thinly sliced"
→ {"name": "red onion", "amount": "½", "notes": "small, thinly sliced", "basicComponent": "onion"}

Input: "2 teaspoons kosher salt"
→ {"name": "kosher salt", "amount": "2 teaspoons", "notes": "", "basicComponent": "salt"}

Input: "1 cup evaporated milk"
→ {"name": "evaporated milk", "amount": "1 cup", "notes": "", "basicComponent": "milk"}

Input: "Sour cream"
→ {"name": "sour cream", "amount": "", "notes": "", "basicComponent": "sour cream"}

Input: "Kosher salt, freshly ground pepper" when "kosher salt" and "black pepper" are already
  listed individually in this recipe's ingredient list
→ DROP — output nothing for this entry (reduces ingredient count by 1)

Input: "salt and pepper to taste" when neither is already listed
→ TWO entries:
  {"name": "kosher salt", "amount": "", "notes": "to taste", "basicComponent": "salt"}
  {"name": "black pepper", "amount": "", "notes": "to taste", "basicComponent": "black pepper"}"""

# ---------------------------------------------------------------------------
# AdditionalInfo conversion
# ---------------------------------------------------------------------------

_COMPLEXITY_MAP = {
    "easy": "Easy", "medium": "Medium", "moderate": "Medium", "hard": "Hard", "difficult": "Hard",
}

def convert_flat_additional_info(flat: dict) -> dict:
    """Convert flat additionalInfo dict from model output to recipes.json format.

    Model outputs:  {"time": "30 min", "servings": 4, "complexity": "Easy"}
    JSON format:    {"infos": [{"time": "30 min"}, {"servings": 4}, {"complexity": "Easy"}]}
    """
    infos = []

    time_val = flat.get("time")
    if isinstance(time_val, str) and time_val.strip():
        infos.append({"time": time_val.strip()})

    servings_val = flat.get("servings")
    if servings_val is not None:
        if isinstance(servings_val, int) and servings_val > 0:
            infos.append({"servings": servings_val})
        elif isinstance(servings_val, str):
            try:
                n = int(servings_val.strip())
                if n > 0:
                    infos.append({"servings": n})
            except ValueError:
                pass

    complexity_val = flat.get("complexity")
    if isinstance(complexity_val, str):
        normalized = _COMPLEXITY_MAP.get(complexity_val.strip().lower())
        if normalized:
            infos.append({"complexity": normalized})

    return {"infos": infos}


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(description="Batch-process recipes.json with DeepSeek.")
    parser.add_argument("--input",  default="../CookSavvy/Support/Assets/recipes.json",
                        help="Source JSON path")
    parser.add_argument("--output", default="../CookSavvy/Support/Assets/recipes_processed.json",
                        help="Output JSON path")
    parser.add_argument("--checkpoint-dir", default="./checkpoints",
                        help="Directory for per-batch checkpoint files")
    parser.add_argument("--batch-size",  type=int, default=100,
                        help="Recipes per API call (also the checkpoint granularity)")
    parser.add_argument("--concurrency", type=int, default=50,
                        help="Max parallel API calls")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only process first N recipes (dry-run mode)")
    parser.add_argument("--model", default="deepseek-v4-flash",
                        help="DeepSeek model ID")
    parser.add_argument("--resume", action="store_true",
                        help="Skip batches that already have a checkpoint file")
    return parser.parse_args()

# ---------------------------------------------------------------------------
# DeepSeek API call — single attempt (no retry here; retry is in process_batch)
# ---------------------------------------------------------------------------

# Windows-1252 C1 control characters that appear verbatim in recipe titles
# because the source data was decoded as latin-1 instead of cp1252.
_WIN1252 = {
    '\x91': '‘', '\x92': '’',  # curly single quotes
    '\x93': '“', '\x94': '”',  # curly double quotes
    '\x95': '•',                    # bullet
    '\x96': '–', '\x97': '—',  # en-dash, em-dash
    '\x99': '™',                    # trademark
}

def _normalize_title(s: str) -> str:
    """Normalize a title for comparison: fix Windows-1252 artifacts, collapse whitespace."""
    for bad, good in _WIN1252.items():
        s = s.replace(bad, good)
    return unicodedata.normalize('NFKC', ' '.join(s.split()))


def _clean_recipe_for_model(r: dict) -> dict:
    """Sanitize a recipe before sending to the model.

    Removes characters that reliably cause the model to emit invalid JSON:
    embedded double-quotes and raw newlines inside ingredient name strings.
    """
    cleaned = dict(r)
    cleaned['ingredients'] = [
        {**ing, 'name': ' '.join(ing['name'].replace('"', "'").split())}
        if isinstance(ing.get('name'), str) else ing
        for ing in r.get('ingredients', [])
    ]
    return cleaned


def _merge_recipes(batch: list[dict], recipes_out: list[dict]) -> list[dict]:
    """Merge model output back onto originals, preserving untouched fields.
    If recipes_out is shorter than batch, the tail is filled with originals.
    """
    merged = []
    for orig, proc in zip(batch, recipes_out):
        m = dict(orig)
        m["ingredients"] = proc.get("ingredients", orig.get("ingredients", []))
        m["instructions"] = proc.get("instructions", orig.get("instructions", []))
        m["cuisine"]      = proc.get("cuisine", orig.get("cuisine"))
        proc_ai = proc.get("additionalInfo")
        if isinstance(proc_ai, dict) and "infos" not in proc_ai:
            m["additionalInfo"] = convert_flat_additional_info(proc_ai)
        elif isinstance(proc_ai, dict):
            m["additionalInfo"] = proc_ai
        merged.append(m)
    # Pad with originals if model returned fewer recipes than expected.
    if len(recipes_out) < len(batch):
        merged.extend(dict(r) for r in batch[len(recipes_out):])
    return merged


async def _call_once(
    session: aiohttp.ClientSession,
    api_key: str,
    model: str,
    batch: list[dict],
    attempt: int,
) -> tuple[list[dict] | None, list[dict] | None, list[str]]:
    """One HTTP round-trip to the DeepSeek endpoint.

    Returns (ok, partial, errors):
      ok      — fully validated merged result (only set on clean success)
      partial — best-effort merge when validation failed but the model returned something
      errors  — list of error strings describing what went wrong
    """
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    input_recipes = [
        {
            "title": r["title"],
            "ingredients": _clean_recipe_for_model(r)["ingredients"],
            "instructions": r.get("instructions", []),
        }
        for r in batch
    ]
    payload = {
        "model": model,
        "temperature": 0,
        # Disable extended thinking so JSON mode works reliably
        "thinking": {"type": "disabled"},
        "response_format": {"type": "json_object"},
        # deepseek-v4-flash supports 384K output tokens; 128K gives headroom for 100-recipe batches
        "max_tokens": 131072,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    f"Process these {len(batch)} recipes:\n"
                    + json.dumps(input_recipes, ensure_ascii=False)
                ),
            },
        ],
    }

    async with session.post(DEEPSEEK_API_URL, headers=headers, json=payload) as resp:
        if resp.status != 200:
            body = await resp.text()
            msg = f"HTTP {resp.status}: {body[:300]}"
            print(f"  [attempt {attempt}] {msg}", file=sys.stderr, flush=True)
            return None, None, [msg]

        data = await resp.json()
        choice = data["choices"][0]
        if choice.get("finish_reason") == "length":
            msg = "Truncated (finish_reason=length) — response cut off"
            print(f"  [attempt {attempt}] {msg}", file=sys.stderr, flush=True)
            return None, None, [msg]

        raw = choice["message"]["content"]
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as exc:
            msg = f"JSON parse error: {exc}"
            print(f"  [attempt {attempt}] {msg}", file=sys.stderr, flush=True)
            return None, None, [msg]

        recipes_out = parsed.get("recipes", [])
        errors = []

        if len(recipes_out) != len(batch):
            errors.append(f"Count mismatch: got {len(recipes_out)}, expected {len(batch)}")

        titles_in  = [_normalize_title(r["title"]) for r in batch]
        titles_out = [_normalize_title(r.get("title", "")) for r in recipes_out]
        if titles_in != titles_out:
            errors.append("Title mismatch")

        merged = _merge_recipes(batch, recipes_out)

        if errors:
            for e in errors:
                print(f"  [attempt {attempt}] {e} — will retry", file=sys.stderr, flush=True)
            return None, merged, errors

        return merged, None, []


async def call_deepseek(
    session: aiohttp.ClientSession,
    api_key: str,
    model: str,
    batch: list[dict],
    batch_index: int,
) -> tuple[list[dict] | None, list[str]]:
    """Retries up to 3 times with 2s/4s/8s backoff.

    Returns (result, errors):
      result — merged recipes (clean on success; best-effort partial if all retries fail)
      errors — empty on success; accumulated error strings if all retries failed
    """
    delays = [2, 4, 8]
    best_partial: list[dict] | None = None
    all_errors: list[str] = []

    for attempt, delay in enumerate(delays, 1):
        try:
            ok, partial, errors = await asyncio.wait_for(
                _call_once(session, api_key, model, batch, attempt),
                timeout=CALL_HARD_TIMEOUT,
            )
            if ok is not None:
                return ok, []
            if partial is not None:
                best_partial = partial
            all_errors.extend(errors)
        except asyncio.TimeoutError:
            msg = f"Timed out after {CALL_HARD_TIMEOUT}s"
            print(f"  Batch {batch_index} attempt {attempt}: {msg}", file=sys.stderr, flush=True)
            all_errors.append(msg)
        except (aiohttp.ClientError, json.JSONDecodeError, KeyError) as exc:
            msg = f"{type(exc).__name__}: {exc}"
            print(f"  Batch {batch_index} attempt {attempt}: {msg}", file=sys.stderr, flush=True)
            all_errors.append(msg)

        if attempt < len(delays):
            print(f"  Batch {batch_index}: retrying in {delay}s …", file=sys.stderr, flush=True)
            await asyncio.sleep(delay)

    return best_partial, all_errors

# ---------------------------------------------------------------------------
# Batch processor
# ---------------------------------------------------------------------------

async def process_batch(
    session: aiohttp.ClientSession,
    api_key: str,
    model: str,
    batch_index: int,
    batch: list[dict],
    checkpoint_dir: Path,
    semaphore: asyncio.Semaphore,
    resume: bool,
    recipe_bar: tqdm,
    batch_bar: tqdm,
    results: dict,
):
    checkpoint_path = checkpoint_dir / f"batch_{batch_index:05d}.json"

    async with semaphore:
        if resume and checkpoint_path.exists():
            async with aiofiles.open(checkpoint_path, "r", encoding="utf-8") as f:
                cp = json.loads(await f.read())
            results[batch_index] = cp
            batch_bar.update(1)
            for _ in cp["recipes"]:
                recipe_bar.update(1)
            return

        t0 = time.monotonic()
        processed, errors = await call_deepseek(session, api_key, model, batch, batch_index)
        elapsed = time.monotonic() - t0

        if not errors:
            cp = {"batch_index": batch_index, "status": "ok", "recipes": processed}
            recipe_bar.write(f"  Batch {batch_index:04d}: OK  ({elapsed:.1f}s)")
        else:
            # Preserve whatever the model returned (partial or None → fall back to originals).
            recipes = processed if processed is not None else batch
            cp = {"batch_index": batch_index, "status": "error", "errors": errors, "recipes": recipes}
            label = "partial model output" if processed is not None else "originals"
            recipe_bar.write(f"  Batch {batch_index:04d}: FAILED — storing {label} ({elapsed:.1f}s)")

        async with aiofiles.open(checkpoint_path, "w", encoding="utf-8") as f:
            await f.write(json.dumps(cp, ensure_ascii=False, indent=2))

        results[batch_index] = cp
        batch_bar.update(1)
        for _ in cp["recipes"]:
            recipe_bar.update(1)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main():
    args = parse_args()

    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        print("Error: DEEPSEEK_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    input_path     = Path(args.input)
    output_path    = Path(args.output)
    checkpoint_dir = Path(args.checkpoint_dir)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading recipes from {input_path} …", flush=True)
    with open(input_path, "r", encoding="utf-8") as f:
        all_recipes = json.load(f)

    if args.limit:
        all_recipes = all_recipes[: args.limit]
        print(f"Dry-run: processing first {len(all_recipes)} recipes.", flush=True)

    total      = len(all_recipes)
    batch_size = args.batch_size
    num_batches = math.ceil(total / batch_size)
    batches = [all_recipes[i * batch_size : (i + 1) * batch_size] for i in range(num_batches)]

    print(
        f"Total recipes: {total} | Batches: {num_batches} | "
        f"Batch size: {batch_size} | Concurrency: {args.concurrency} | Model: {args.model}",
        flush=True,
    )

    semaphore = asyncio.Semaphore(args.concurrency)
    results: dict[int, dict] = {}

    # connect=15: fail fast if the server isn't reachable
    # sock_read=85: abort if no bytes arrive within 85s (covers slow LLM streaming starts)
    # total=100: absolute ceiling per request
    timeout   = aiohttp.ClientTimeout(connect=15, sock_read=85, total=100)
    connector = aiohttp.TCPConnector(limit=args.concurrency + 5)

    start = time.monotonic()

    async with aiohttp.ClientSession(connector=connector, timeout=timeout) as session:
        with tqdm(total=num_batches, unit="batch",  desc="Batches ", position=0, leave=True, file=sys.stdout) as batch_bar, \
             tqdm(total=total,       unit="recipe", desc="Recipes ", position=1, leave=True, file=sys.stdout) as recipe_bar:
            tasks = [
                process_batch(
                    session, api_key, args.model,
                    idx, batch, checkpoint_dir,
                    semaphore, args.resume, recipe_bar, batch_bar, results,
                )
                for idx, batch in enumerate(batches)
            ]
            await asyncio.gather(*tasks)

    elapsed = time.monotonic() - start

    # Merge checkpoints in order
    final_recipes = []
    ok_count = error_count = 0
    for idx in range(num_batches):
        cp = results.get(idx)
        if cp is None:
            print(f"Warning: missing checkpoint for batch {idx}", file=sys.stderr)
            continue
        final_recipes.extend(cp["recipes"])
        if cp["status"] == "ok":
            ok_count += 1
        else:
            error_count += 1

    print(f"\nWriting {len(final_recipes)} recipes to {output_path} …", flush=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(final_recipes, f, ensure_ascii=False, indent=2)

    est_input_tokens  = total * 400
    est_output_tokens = total * 350
    est_cost = (est_input_tokens / 1_000_000) * INPUT_COST_PER_M + \
               (est_output_tokens / 1_000_000) * OUTPUT_COST_PER_M

    print(
        f"\n--- Summary ---\n"
        f"  Batches OK:      {ok_count}/{num_batches}\n"
        f"  Batches errored: {error_count}\n"
        f"  Elapsed:         {elapsed:.1f}s\n"
        f"  Est. cost:       ${est_cost:.2f}\n"
        f"  Output:          {output_path}",
        flush=True,
    )


if __name__ == "__main__":
    asyncio.run(main())
