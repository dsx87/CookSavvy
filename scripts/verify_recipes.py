#!/usr/bin/env python3
"""
Post-process verifier for recipes_processed.json.

Compares the processed file against the original, flags suspicious changes,
and produces a clean output where flagged recipes are substituted back with
their originals.

Usage:
    python verify_recipes.py ORIGINAL PROCESSED \
        [--issues-out issues.json] \
        [--clean-out clean_processed.json]
"""

import argparse
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Token-set check stop-words
# ---------------------------------------------------------------------------

STOP_WORDS = {
    # prep verbs / adjectives
    "finely", "coarsely", "roughly", "thinly", "thickly", "chopped", "minced", "diced",
    "sliced", "grated", "shredded", "peeled", "trimmed", "halved", "quartered", "crushed",
    "mashed", "toasted", "roasted", "ground", "divided", "melted", "softened", "sifted",
    # qualifiers
    "kosher", "sea", "large", "small", "medium", "extra", "fresh", "freshly", "dried",
    "whole", "raw", "about", "approximately", "plus", "more", "such", "as", "or",
    # units
    "tablespoon", "tablespoons", "tbsp", "teaspoon", "teaspoons", "tsp", "cup", "cups",
    "pound", "pounds", "lb", "lbs", "ounce", "ounces", "oz", "gram", "grams", "g",
    "liter", "litre", "ml", "inch", "inches",
}


def token_set(s: str) -> set[str]:
    """Lowercased alphabetic tokens from `s`, excluding stop-words and bare digits."""
    tokens = re.sub(r"[^a-z\s]", " ", s.lower()).split()
    return {t for t in tokens if t not in STOP_WORDS and not t.isdigit()}


# ---------------------------------------------------------------------------
# Per-recipe checks
# ---------------------------------------------------------------------------

def check_recipe(idx: int, orig: dict, proc: dict) -> list[dict]:
    """
    Returns a list of issue dicts for this recipe pair.
    Each issue has: index, title, issue_type, detail.
    """
    issues = []
    title  = orig.get("title", f"[recipe {idx}]")

    def issue(issue_type: str, detail: str):
        issues.append({"index": idx, "title": title, "issue_type": issue_type, "detail": detail})

    # 1. Title must match verbatim
    if orig.get("title") != proc.get("title"):
        issue("title_mismatch", f"Expected {orig.get('title')!r}, got {proc.get('title')!r}")

    # 2. Ingredient count must match
    orig_ings = orig.get("ingredients", [])
    proc_ings = proc.get("ingredients", [])
    if len(orig_ings) != len(proc_ings):
        issue(
            "ingredient_count_mismatch",
            f"Expected {len(orig_ings)} ingredients, got {len(proc_ings)}",
        )
    else:
        # 3. Token-set check per ingredient (1-token tolerance)
        for i, (o_ing, p_ing) in enumerate(zip(orig_ings, proc_ings)):
            orig_str  = o_ing.get("name", "")
            proc_name = p_ing.get("name", "")
            proc_notes = p_ing.get("notes", "") or ""
            combined  = proc_name + " " + proc_notes

            orig_tokens = token_set(orig_str)
            proc_tokens = token_set(combined)
            hallucinated = proc_tokens - orig_tokens

            if len(hallucinated) > 1:
                issue(
                    "token_hallucination",
                    f"Ingredient {i}: original {orig_str!r} → name={proc_name!r} notes={proc_notes!r}; "
                    f"new tokens not in original: {hallucinated}",
                )

    # 4. Instruction step count: warn if outside 50%–200% of original
    orig_steps = orig.get("instructions", [])
    proc_steps = proc.get("instructions", [])
    if orig_steps:
        ratio = len(proc_steps) / len(orig_steps)
        if ratio < 0.5 or ratio > 2.0:
            issue(
                "instruction_count_warning",
                f"Original had {len(orig_steps)} steps, processed has {len(proc_steps)} "
                f"(ratio {ratio:.1f})",
            )

    # 5. Cuisine must be a string or null
    cuisine = proc.get("cuisine")
    if cuisine is not None and not isinstance(cuisine, str):
        issue("invalid_cuisine", f"cuisine must be a string or null, got {type(cuisine).__name__}")

    return issues


# ---------------------------------------------------------------------------
# Determine which issues are blocking (recipe reverted to original)
# ---------------------------------------------------------------------------

BLOCKING_ISSUE_TYPES = {
    "title_mismatch",
    # ingredient_count_mismatch is a warning: combined "salt and pepper" entries may be
    # split into two or dropped when duplicates, intentionally changing the count.
    "token_hallucination",
    "invalid_cuisine",
}


def is_blocking(issue: dict) -> bool:
    return issue["issue_type"] in BLOCKING_ISSUE_TYPES


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(description="Verify and clean a processed recipes JSON.")
    parser.add_argument("original",  help="Path to original recipes.json")
    parser.add_argument("processed", help="Path to recipes_processed.json")
    parser.add_argument("--issues-out",  default="issues.json",          help="Output path for issue report")
    parser.add_argument("--clean-out",   default="clean_processed.json", help="Output path for cleaned JSON")
    return parser.parse_args()


def main():
    args = parse_args()

    print(f"Loading original: {args.original}")
    with open(args.original, "r", encoding="utf-8") as f:
        originals = json.load(f)

    print(f"Loading processed: {args.processed}")
    with open(args.processed, "r", encoding="utf-8") as f:
        processed = json.load(f)

    # Fatal check: total recipe count must match
    if len(originals) != len(processed):
        print(
            f"\nFATAL: Recipe count mismatch — original has {len(originals)}, "
            f"processed has {len(processed)}. Aborting.",
            file=sys.stderr,
        )
        sys.exit(1)

    total = len(originals)
    all_issues: list[dict] = []
    flagged_indices: set[int] = set()
    warning_indices: set[int] = set()

    for idx, (orig, proc) in enumerate(zip(originals, processed)):
        issues = check_recipe(idx, orig, proc)
        if issues:
            all_issues.extend(issues)
            for iss in issues:
                if is_blocking(iss):
                    flagged_indices.add(idx)
                else:
                    warning_indices.add(idx)

    # Build clean output: substitute flagged recipes back with originals
    clean: list[dict] = []
    for idx, proc in enumerate(processed):
        if idx in flagged_indices:
            clean.append(originals[idx])
        else:
            clean.append(proc)

    # Write outputs
    issues_path = Path(args.issues_out)
    clean_path  = Path(args.clean_out)

    with open(issues_path, "w", encoding="utf-8") as f:
        json.dump(all_issues, f, ensure_ascii=False, indent=2)

    with open(clean_path, "w", encoding="utf-8") as f:
        json.dump(clean, f, ensure_ascii=False, indent=2)

    # Tally by issue type for the summary
    type_counts: dict[str, int] = {}
    for iss in all_issues:
        type_counts[iss["issue_type"]] = type_counts.get(iss["issue_type"], 0) + 1

    # Only count a recipe as warning-only if it has no blocking issues
    warning_only = warning_indices - flagged_indices
    clean_count  = total - len(flagged_indices)

    print(
        f"\n--- Verification Summary ---\n"
        f"  Total recipes:    {total}\n"
        f"  Clean (accepted): {clean_count}\n"
        f"  Flagged (reverted to original): {len(flagged_indices)}\n"
        f"  Warnings only:    {len(warning_only)}\n"
    )
    if type_counts:
        print("  Issue breakdown:")
        for issue_type, count in sorted(type_counts.items()):
            print(f"    {issue_type}: {count}")

    print(
        f"\n  Issues written to:  {issues_path}\n"
        f"  Clean output:       {clean_path}\n"
    )

    if len(flagged_indices) > 0:
        print(
            "  Review issues.json before copying clean_processed.json → recipes.json"
        )
    else:
        print("  No blocking issues found. clean_processed.json is ready to use.")


if __name__ == "__main__":
    main()
