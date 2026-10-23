#!/usr/bin/env python3
"""Compares this repository's copy of playable_kit with another checkout.

The kit is shared by two games that live in separate repositories, so there
are two copies of it and nothing in git keeps them equal. This says whether
they still are, and exits non-zero when they are not, so it can gate a
commit.

Usage:
    python tools/compare_kit.py ../merge-run
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
KIT = Path("packages/playable_kit")

#: Directories that are output rather than source.
IGNORED = {"build", ".dart_tool"}


def fingerprints(root: Path) -> dict[str, str]:
    kit = root / KIT
    if not kit.is_dir():
        raise SystemExit(f"no kit at {kit}")

    found: dict[str, str] = {}
    for path in sorted(kit.rglob("*")):
        if not path.is_file():
            continue
        if any(part in IGNORED for part in path.relative_to(kit).parts):
            continue
        if path.name == "pubspec.lock":
            continue

        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        found[path.relative_to(kit).as_posix()] = digest

    return found


def main(other: str) -> int:
    here = fingerprints(REPO_ROOT)
    there = fingerprints(Path(other).resolve())

    only_here = sorted(set(here) - set(there))
    only_there = sorted(set(there) - set(here))
    changed = sorted(name for name in set(here) & set(there)
                     if here[name] != there[name])

    for name in only_here:
        print(f"  only here   {name}")
    for name in only_there:
        print(f"  only there  {name}")
    for name in changed:
        print(f"  differs     {name}")

    if not (only_here or only_there or changed):
        print(f"the kit matches {other} ({len(here)} files)")
        return 0

    print()
    print(f"{len(only_here) + len(only_there) + len(changed)} difference(s). "
          "The copies have drifted; decide which is right and copy it over.")
    return 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: compare_kit.py <path to the other checkout>")
    raise SystemExit(main(sys.argv[1]))
