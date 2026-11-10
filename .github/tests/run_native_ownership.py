"""Compile actual plugin sources and the complete unmodified SDK; never build a bundle."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
BASELINE = "8a3b5ec7866c19c80611a23984ff657c787a6436"
SDK_SHA256 = "2721c3d4338cc2a350599ffcee2a8008abaa756acfd45dd710720c64ca8c8ce3"
SCENARIOS = ("text", "path", "path-empty", "bytes", "copy", "copy-empty",
             "gray", "size", "thumbnail")
DEFECTS = {
    "path": "double string disposal",
    "path-empty": "picture reference balance",
    "bytes": "picture reference balance",
    "copy": "AddressSanitizer: heap-buffer-overflow",
    "copy-empty": "string allocation balance",
    "gray": "picture reference balance",
    "size": "picture reference balance",
    "thumbnail": "picture reference balance",
}


def build(destination, revision=None):
    names = subprocess.check_output(
        ["git", "ls-files", "*.cpp", "*.c", "*.h"], cwd=ROOT, text=True
    ).splitlines()
    sources = []
    for name in names:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        content = (subprocess.check_output(["git", "show", f"{revision}:{name}"], cwd=ROOT)
                   if revision else (ROOT / name).read_bytes())
        target.write_bytes(content)
        if target.suffix in (".c", ".cpp"):
            sources.append(target)
    sdk = destination / "4D Plugin API/4DPluginAPI.c"
    if hashlib.sha256(sdk.read_bytes()).hexdigest() != SDK_SHA256:
        raise RuntimeError("Bundled SDK changed: re-establish engine-boundary contracts")
    binary = destination / "native-ownership"
    subprocess.run([
        "clang++", "-std=c++11", "-x", "objective-c++", "-include", "Carbon/Carbon.h",
        "-I", str(destination / "4D Plugin API"),
        "-I", str(destination / "4D Plugin API/Classes"),
        "-fsanitize=address,undefined", "-fno-omit-frame-pointer", "-g", "-O1",
        "-Wno-deprecated-declarations", "-Wno-return-type-c-linkage",
        *map(str, sources), str(ROOT / ".github/tests/native_ownership.mm"),
        "-framework", "Cocoa", "-framework", "Carbon", "-framework", "SystemConfiguration",
        "-o", str(binary),
    ], check=True, cwd=ROOT)
    return binary


def run(binary, scenario, empty, outcome):
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0:halt_on_error=1",
               UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1")
    return subprocess.run([str(binary), scenario, empty, outcome], env=env,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-baseline", action="store_true")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="addresses-ownership-") as directory:
        temp = Path(directory)
        fixed = build(temp / "current")
        for empty in ("allocated", "null"):
            for scenario in SCENARIOS:
                for outcome in ("success", "failure"):
                    result = run(fixed, scenario, empty, outcome)
                    print(result.stdout, end="")
                    if result.returncode:
                        raise SystemExit(result.returncode)
        if args.verify_baseline:
            original = build(temp / "baseline", BASELINE)
            for scenario in SCENARIOS:
                empty = "null" if scenario == "path-empty" else "allocated"
                result = run(original, scenario, empty, "success")
                if scenario == "text":
                    if result.returncode:
                        print(result.stdout)
                        raise SystemExit("Unchanged text-array control must pass baseline")
                    print("BASELINE PASS: text-array ownership control")
                else:
                    if result.returncode == 0 or DEFECTS[scenario] not in result.stdout:
                        print(result.stdout)
                        raise SystemExit(f"Baseline did not fail named defect: {scenario}")
                    print(f"BASELINE FAIL (expected): {scenario}: {DEFECTS[scenario]}")


if __name__ == "__main__":
    main()
