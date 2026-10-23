#!/usr/bin/env python3
"""Measure build artefacts against the budgets in docs/performance-budget.md.

A budget written only in a document drifts the moment someone adds a
dependency. This script makes it checkable: it prints every artefact it can
find, flags the ones over budget, and exits non-zero so it can gate a commit.

Missing artefacts are reported as skipped rather than failed, because not every
target is built on every machine.

Usage:
    python tools/size_report.py
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

MIB = 1024 * 1024
KIB = 1024

REPO_ROOT = Path(__file__).resolve().parent.parent

#: How many of the largest files to list when an artefact is over budget.
TOP_CONTRIBUTORS = 8


@dataclass(frozen=True)
class Target:
    """One artefact and the size it is allowed to reach."""

    label: str
    #: Glob relative to the repository root. A directory match is summed
    #: recursively; file matches are reported individually.
    pattern: str
    budget_bytes: int
    note: str = ""


TARGETS: tuple[Target, ...] = (
    Target(
        label="Windows release (directory)",
        pattern="apps/*/build/windows/x64/runner/Release",
        budget_bytes=28 * MIB,
        note="20.3 MB of this is the fixed Flutter engine DLL",
    ),
    # Three Android budgets rather than one, because the APKs are not
    # comparable: an x86_64 build of the same code is wider than an ARM one,
    # and the universal APK carries all three machine codes at once.
    Target(
        label="Android APK per ABI (shipped)",
        pattern="apps/*/build/app/outputs/flutter-apk/app-arm*-release.apk",
        budget_bytes=18 * MIB,
        note="most of this is the fixed Flutter engine: 11.2 MB on arm64",
    ),
    Target(
        label="Android APK x86_64 (emulators only)",
        pattern="apps/*/build/app/outputs/flutter-apk/app-x86_64-release.apk",
        budget_bytes=20 * MIB,
        note="never shipped, so it is budgeted apart from the ARM builds",
    ),
    Target(
        label="Android APK universal",
        pattern="apps/*/build/app/outputs/flutter-apk/app-release.apk",
        budget_bytes=50 * MIB,
        note="all three ABIs in one file; for sideloading without choosing",
    ),
    # One per game core, because the claim each of them makes is its own:
    # that its rules compile to JavaScript and stay small enough for a web
    # playable. A document asserting that would rot; this compiles or it
    # does not.
    Target(
        label="Compiled core for web (dart2js)",
        pattern="packages/*/build/core.js",
        budget_bytes=300 * KIB,
    ),
)


def directory_size(path: Path) -> int:
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def largest_files(path: Path, count: int) -> list[tuple[int, Path]]:
    files = ((item.stat().st_size, item) for item in path.rglob("*") if item.is_file())
    return sorted(files, reverse=True)[:count]


def describe(match: Path) -> str:
    """Names one artefact among several, so two games can be told apart.

    `match.name` alone is not enough: both games' Windows builds are a
    directory called `Release`, and a report with two lines reading
    "Release" is a report nobody can act on.
    """
    parts = match.relative_to(REPO_ROOT).parts
    if len(parts) > 1 and parts[0] in {"apps", "packages"}:
        return f"{parts[1]} / {match.name}"
    return match.name


def format_size(size_bytes: int) -> str:
    if size_bytes >= MIB:
        return f"{size_bytes / MIB:7.2f} MB"
    return f"{size_bytes / KIB:7.1f} KB"


def report_target(target: Target) -> bool | None:
    """Prints one target. Returns True if within budget, False if over, None if absent."""
    matches = sorted(REPO_ROOT.glob(target.pattern))
    if not matches:
        print(f"  skipped  {target.label}")
        print(f"           not built ({target.pattern})")
        return None

    all_within = True
    for match in matches:
        size = directory_size(match) if match.is_dir() else match.stat().st_size
        within = size <= target.budget_bytes
        all_within = all_within and within

        name = describe(match) if len(matches) > 1 else target.label
        verdict = "ok" if within else "OVER"
        print(
            f"  {verdict:>7}  {name}\n"
            f"           {format_size(size)}  of  {format_size(target.budget_bytes)}"
        )
        if target.note:
            print(f"           {target.note}")

        if not within and match.is_dir():
            print("           largest contributors:")
            for file_size, file_path in largest_files(match, TOP_CONTRIBUTORS):
                relative = file_path.relative_to(match)
                print(f"             {format_size(file_size)}  {relative}")

    return all_within


def main() -> int:
    print(f"Size report for {REPO_ROOT}\n")

    over_budget = 0
    measured = 0
    for target in TARGETS:
        result = report_target(target)
        print()
        if result is None:
            continue
        measured += 1
        if not result:
            over_budget += 1

    if measured == 0:
        print("Nothing was built. Build a target first, then re-run.")
        return 0

    if over_budget:
        print(f"{over_budget} of {measured} artefacts are over budget.")
        return 1

    print(f"All {measured} measured artefacts are within budget.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
