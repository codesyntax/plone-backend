#!/usr/bin/env python3
"""Merge a user-supplied ``instance.yaml`` over the baked default.

The top level is merged shallowly, but dict-valued keys (such as
``default_context.environment`` and ``default_context.logging_loggers``) are
merged deeply, so a sparse user file inherits the remaining baked defaults.

Usage: ``merge_instance.py DEFAULT USER OUTPUT``
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml


def _load(path: Path) -> dict[str, Any]:
    with open(path) as handle:
        return yaml.safe_load(handle) or {}


def deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> None:
    """Merge ``overlay`` into ``base`` in place, recursing into shared dicts."""
    for key, value in overlay.items():
        if isinstance(base.get(key), dict) and isinstance(value, dict):
            deep_merge(base[key], value)
        else:
            base[key] = value


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: merge_instance.py DEFAULT USER OUTPUT", file=sys.stderr)
        return 2

    default_path, user_path, out_path = Path(argv[1]), Path(argv[2]), Path(argv[3])
    data = _load(default_path)

    if user_path.is_file():
        deep_merge(data, _load(user_path))

    with open(out_path, "w") as handle:
        yaml.safe_dump(data, handle, sort_keys=False)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
