"""Measure the frame, unattended.

Runs the Windows profile build with the autopilot on, collects the
``FRAMESTATS`` lines the app prints every few seconds, and reports the
aggregate. Written as a script rather than as a checklist because the two
measurements that were thrown away during this project were both thrown away
by hand: one with the window buried behind the editor, one stopped before the
numbers had settled.

The trap worth knowing: **a fully occluded window stops producing frames.**
The engine has nothing to present, ``FrameTiming`` never fires, and the run
finishes with an empty report while the process looks perfectly healthy. So
this script pushes the window to the front itself and says whether it managed
to, and it discards the opening seconds while shaders warm up.

It builds first and then measures through ``flutter run``, which is slower
to start but is the only way to read the app's output at all: the Windows
runner is a GUI binary with no stdout of its own, so launching the executable
directly and piping it returns nothing. That cost an empty run to discover,
which is exactly the kind of thing this script exists to stop happening
twice. Pre-building means the ``flutter run`` that follows is incremental and
reaches the first frame in seconds.

Usage::

    python tools/frame_report.py [app] [--seconds 40] [--level 0] [--no-build]

``app`` is ``neon_dash`` (the default) or ``merge_run``.

Exit code is non-zero when the frame budget was missed, so it can gate a
commit.
"""

from __future__ import annotations

import argparse
import ctypes
import os
import re
import statistics
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

#: Every app this harness can drive, and the dart-defines each one reads.
#:
#: Two games now share the harness, and they do not share a namespace for
#: their defines. Listing them here rather than guessing keeps the script
#: from silently measuring a build with the autopilot switched off, which
#: looks exactly like a measurement of a game nobody is playing.
APPS: dict[str, dict[str, str]] = {
    "neon_dash": {
        "autopilot": "neon_dash.autopilot",
        "level": "neon_dash.level",
    },
    "merge_run": {
        "autopilot": "merge_run.autopilot",
    },
}

# 120 Hz is the target the simulation runs at; 60 Hz is the floor below which
# the game stops feeling like this genre should.
BUDGET_120_MS = 8.33
BUDGET_60_MS = 16.67

# Shaders compile on the first frames that need them, and on a cold start that
# is not what anyone experiences for more than a second. Measured anyway, but
# reported separately rather than averaged into the steady state.
WARMUP_SECONDS = 8.0

# How long to wait for the window before giving up on it. An incremental
# build plus engine start is a few seconds; a cold one is not.
LAUNCH_GRACE_SECONDS = 180.0

LINE = re.compile(
    r"FRAMESTATS frames=(?P<frames>\d+) "
    r"build p50=(?P<build_p50>[\d.]+) p95=(?P<build_p95>[\d.]+) "
    r"max=(?P<build_max>[\d.]+) \| "
    r"raster p50=(?P<raster_p50>[\d.]+) p95=(?P<raster_p95>[\d.]+) "
    r"max=(?P<raster_max>[\d.]+) \| "
    r"late60=(?P<late60>\d+) late120=(?P<late120>\d+)"
)


@dataclass
class Window:
    """One ``FRAMESTATS`` report."""

    at: float
    frames: int
    build_p50: float
    build_p95: float
    build_max: float
    raster_p50: float
    raster_p95: float
    raster_max: float
    late60: int
    late120: int


# What `flutter run` prints once the app is actually up. Until one of these
# appears the build is still going, and anything that looks like the app's
# window belongs to something else.
READY_MARKERS = (
    "Dart VM Service",
    "Flutter run key commands",
    "Application finished",
)


@dataclass
class Collector:
    """Reads the app's stdout on its own thread."""

    windows: list[Window] = field(default_factory=list)
    started: float = field(default_factory=time.monotonic)
    lock: threading.Lock = field(default_factory=threading.Lock)
    ready: threading.Event = field(default_factory=threading.Event)

    def feed(self, line: str) -> None:
        if not self.ready.is_set() and any(m in line for m in READY_MARKERS):
            self.ready.set()
        self._parse(line)

    def _parse(self, line: str) -> None:
        match = LINE.search(line)
        if match is None:
            return
        values = match.groupdict()
        window = Window(
            at=time.monotonic() - self.started,
            frames=int(values["frames"]),
            build_p50=float(values["build_p50"]),
            build_p95=float(values["build_p95"]),
            build_max=float(values["build_max"]),
            raster_p50=float(values["raster_p50"]),
            raster_p95=float(values["raster_p95"]),
            raster_max=float(values["raster_max"]),
            late60=int(values["late60"]),
            late120=int(values["late120"]),
        )
        with self.lock:
            self.windows.append(window)


def raise_window(own_pid: int, title: str) -> bool:
    """Bring the app's window to the front. Returns whether it worked.

    Without this the measurement silently collects nothing: see the module
    docstring. Matched on the exact title from `windows/runner/main.cpp` and
    never on this script's own process, because a console titled with the
    command line would otherwise be raised instead of the app. The window
    belongs to a grandchild of this script — `flutter run` spawns it — so its
    process id cannot be known in advance.
    """
    user32 = ctypes.windll.user32
    found: list[int] = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def visit(handle, _):
        if not user32.IsWindowVisible(handle):
            return True

        owner = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
        if owner.value == own_pid:
            return True

        length = user32.GetWindowTextLengthW(handle)
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(handle, buffer, length + 1)
        if buffer.value == title:
            found.append(handle)
            return False
        return True

    user32.EnumWindows(visit, None)
    if not found:
        return False

    handle = found[0]
    sw_restore = 9
    user32.ShowWindow(handle, sw_restore)
    return bool(user32.SetForegroundWindow(handle))


def pump(stream, collector: Collector, echo: bool) -> None:
    """Drains the child's output forever.

    Everything is inside the guard: a reader thread that dies takes the whole
    measurement with it and says nothing, which is how one run was lost to a
    console that could not encode a tick mark.
    """
    try:
        for raw in iter(stream.readline, ""):
            line = raw.rstrip()
            if echo:
                print(f"  | {line}")
            collector.feed(line)
    except Exception as error:  # noqa: BLE001 - reported, never raised
        print(f"  (output reader stopped: {error})")


def summarise(windows: list[Window], seconds: float) -> int:
    steady = [w for w in windows if w.at >= WARMUP_SECONDS]
    warmup = [w for w in windows if w.at < WARMUP_SECONDS]

    print()
    print(f"collected {len(windows)} windows over {seconds:.0f}s "
          f"({len(warmup)} during warm-up)")

    if not steady:
        print()
        print("NO STEADY-STATE FRAMES.")
        print("The window was probably never visible - see the note in")
        print("docs/performance-budget.md. Nothing was measured.")
        return 2

    frames = sum(w.frames for w in steady)
    late60 = sum(w.late60 for w in steady)
    late120 = sum(w.late120 for w in steady)

    def across(attribute: str, how) -> float:
        return how(getattr(w, attribute) for w in steady)

    print()
    print(f"  frames          {frames}")
    print(f"  build  p50      {statistics.median(w.build_p50 for w in steady):.2f} ms")
    print(f"  build  p95      {across('build_p95', max):.2f} ms")
    print(f"  build  max      {across('build_max', max):.2f} ms")
    print(f"  raster p50      {statistics.median(w.raster_p50 for w in steady):.2f} ms")
    print(f"  raster p95      {across('raster_p95', max):.2f} ms")
    print(f"  raster max      {across('raster_max', max):.2f} ms")
    print(f"  late (>{BUDGET_60_MS} ms)  {late60}")
    print(f"  late (>{BUDGET_120_MS} ms)   {late120}")

    if warmup:
        print()
        print(f"  warm-up raster max {max(w.raster_max for w in warmup):.2f} ms")

    worst = max(across("build_max", max), across("raster_max", max))
    print()
    if late60 > 0:
        print(f"OVER BUDGET: {late60} frames missed 60 Hz.")
        return 1
    if worst > BUDGET_60_MS:
        print(f"OVER BUDGET: worst frame {worst:.2f} ms.")
        return 1

    print(f"within budget: worst frame {worst:.2f} ms against "
          f"{BUDGET_60_MS} ms.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", nargs="?", default="neon_dash",
                        choices=sorted(APPS),
                        help="which game to measure")
    parser.add_argument("--seconds", type=float, default=40.0,
                        help="how long to measure, warm-up included")
    parser.add_argument("--level", type=int, default=0,
                        help="which level the autopilot flies, where the "
                             "game has levels")
    parser.add_argument("--quiet", action="store_true",
                        help="do not echo the app's output")
    parser.add_argument("--no-build", dest="build", action="store_false",
                        help="run the binary that is already there")
    args = parser.parse_args()

    # The app's own output is not ASCII, and a Windows console defaulting to
    # a legacy code page will raise rather than print it.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    if sys.platform != "win32":
        print("This harness drives the Windows build.")
        return 2

    keys = APPS[args.app]
    app_dir = REPO_ROOT / "apps" / args.app
    exe = (app_dir / "build" / "windows" / "x64" / "runner" / "Profile"
           / f"{args.app}.exe")
    # The title `windows/runner/main.cpp` gives the window.
    window_title = args.app

    defines = [f"--dart-define={keys['autopilot']}=true"]
    if "level" in keys:
        defines.append(f"--dart-define={keys['level']}={args.level}")

    if args.build:
        print("building the profile binary ...")
        built = subprocess.run(
            ["flutter", "build", "windows", "--profile", *defines],
            cwd=app_dir,
            shell=True,
            check=False,
        )
        if built.returncode != 0:
            print("the build failed")
            return 2

    if not exe.exists():
        print(f"no binary at {exe}")
        return 2

    command = ["flutter", "run", "--profile", "-d", "windows", *defines]
    print(f"running: {' '.join(command)}")
    process = subprocess.Popen(
        command,
        cwd=app_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
        shell=True,
    )

    collector = Collector()
    reader = threading.Thread(
        target=pump,
        args=(process.stdout, collector, not args.quiet),
        daemon=True,
    )
    reader.start()

    # Nothing is raised until `flutter run` says the app is up. A window
    # titled like the app can exist before then — an editor tab, this
    # script's own console — and raising one of those would start the clock
    # during the build and measure an app that had not launched yet.
    raised = False
    # The clock starts once the window is up, so a slow start does not eat
    # the measurement; until then this only bounds how long to wait for one.
    deadline = time.monotonic() + args.seconds + LAUNCH_GRACE_SECONDS
    while time.monotonic() < deadline:
        if not raised and collector.ready.is_set():
            raised = raise_window(os.getpid(), window_title)
            if raised:
                print("  (window brought to the front)")
                collector.started = time.monotonic()
        if raised and time.monotonic() - collector.started >= args.seconds:
            break
        if process.poll() is not None:
            print("the app exited early")
            break
        time.sleep(0.5)

    if not raised:
        where = "it never started" if not collector.ready.is_set() \
            else "it started but its window was not found"
        print(f"  (no measurement: {where})")

    # `flutter run` stops on `q`; killing it would leave the app running.
    try:
        process.stdin.write("q\n")
        process.stdin.flush()
    except OSError:
        pass
    try:
        process.wait(timeout=30)
    except subprocess.TimeoutExpired:
        process.kill()

    with collector.lock:
        windows = list(collector.windows)
    return summarise(windows, args.seconds)


if __name__ == "__main__":
    raise SystemExit(main())
