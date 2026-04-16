#!/usr/bin/env python3
"""
model_usage.py — Summarize per-model cost from CodexBar cost JSON.

Usage:
  python model_usage.py --provider codex --mode current
  python model_usage.py --provider claude --mode all --format json --pretty
  python model_usage.py --input /tmp/cost.json --mode all
  cat cost.json | python model_usage.py --input - --mode current
"""

import argparse
import json
import subprocess
import sys


def load_json(args):
    if args.input:
        if args.input == "-":
            data = json.load(sys.stdin)
        else:
            with open(args.input) as f:
                data = json.load(f)
    else:
        try:
            result = subprocess.run(
                ["codexbar", "cost", "--format", "json", "--provider", args.provider],
                capture_output=True,
                text=True,
                check=True,
            )
            data = json.loads(result.stdout)
        except FileNotFoundError:
            print(
                "error: codexbar CLI not found. On Linux/WSL2 use --input to pass a cost JSON file.",
                file=sys.stderr,
            )
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            print(f"error: codexbar exited with error:\n{e.stderr}", file=sys.stderr)
            sys.exit(1)
    return data


def pick_current_model(entries):
    """Return (model_name, cost) from the most recent entry with modelBreakdowns."""
    for entry in reversed(entries):
        breakdowns = entry.get("modelBreakdowns")
        if breakdowns:
            model = max(breakdowns, key=lambda m: breakdowns[m])
            return model, breakdowns[model]
    # fallback: last entry modelsUsed
    for entry in reversed(entries):
        models_used = entry.get("modelsUsed")
        if models_used:
            return models_used[-1], None
    return None, None


def aggregate_all_models(entries):
    """Return dict of {model: total_cost} across all entries."""
    totals = {}
    for entry in entries:
        breakdowns = entry.get("modelBreakdowns") or {}
        for model, cost in breakdowns.items():
            totals[model] = totals.get(model, 0.0) + cost
    return dict(sorted(totals.items(), key=lambda x: x[1], reverse=True))


def run(args):
    entries = load_json(args)
    if not isinstance(entries, list):
        entries = [entries]

    if args.mode == "current":
        model, cost = pick_current_model(entries)
        if model is None:
            print("No model data found.", file=sys.stderr)
            sys.exit(1)

        if args.format == "json":
            out = {"model": model, "cost": cost}
            print(json.dumps(out, indent=2 if args.pretty else None))
        else:
            cost_str = f"${cost:.6f}" if cost is not None else "n/a"
            print(f"Current model : {model}")
            print(f"Cost          : {cost_str}")

    elif args.mode == "all":
        totals = aggregate_all_models(entries)
        if not totals:
            print("No modelBreakdowns found in any entry.", file=sys.stderr)
            sys.exit(1)

        if args.format == "json":
            out = [{"model": m, "total_cost": c} for m, c in totals.items()]
            print(json.dumps(out, indent=2 if args.pretty else None))
        else:
            width = max(len(m) for m in totals)
            print(f"{'Model':<{width}}  Total Cost")
            print("-" * (width + 14))
            for model, cost in totals.items():
                print(f"{model:<{width}}  ${cost:.6f}")


def main():
    parser = argparse.ArgumentParser(description="Summarize CodexBar per-model cost usage.")
    parser.add_argument(
        "--provider", choices=["codex", "claude"], default="claude",
        help="Provider to query via codexbar (ignored when --input is set).",
    )
    parser.add_argument(
        "--mode", choices=["current", "all"], default="current",
        help="'current' = most recent model, 'all' = full breakdown.",
    )
    parser.add_argument(
        "--input", metavar="FILE",
        help="Path to cost JSON file, or '-' to read from stdin.",
    )
    parser.add_argument(
        "--model", metavar="NAME",
        help="Override: show cost for a specific model name (mode=current only).",
    )
    parser.add_argument(
        "--format", choices=["text", "json"], default="text",
        help="Output format.",
    )
    parser.add_argument(
        "--pretty", action="store_true",
        help="Pretty-print JSON output (only with --format json).",
    )
    args = parser.parse_args()

    if args.model and args.mode == "current":
        # manual override: find this specific model across all entries
        entries = load_json(args)
        if not isinstance(entries, list):
            entries = [entries]
        total = sum(
            e.get("modelBreakdowns", {}).get(args.model, 0.0) for e in entries
        )
        if args.format == "json":
            out = {"model": args.model, "cost": total}
            print(json.dumps(out, indent=2 if args.pretty else None))
        else:
            print(f"Model  : {args.model}")
            print(f"Cost   : ${total:.6f}")
        return

    run(args)


if __name__ == "__main__":
    main()
