#!/usr/bin/env python3
"""Run an opt-in Aether comparison on a paired physical device, without player saves.

Requires a signed build containing AetherReleaseValidation and an unlocked device.
This does not build, register devices, change signing, or access online accounts.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Paired device name or UDID")
    parser.add_argument("--variant", choices=["baseline", "candidate", "comparison"], required=True)
    parser.add_argument("--quality", choices=["balanced", "full"], default="balanced")
    parser.add_argument("--seconds", type=float, default=45)
    parser.add_argument("--passes", type=int, default=2)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline-output", type=Path, help="Required for the paired comparison")
    parser.add_argument("--install", type=Path, help="Optional signed AlpineFlight.app to install first")
    args = parser.parse_args()
    if not 5 <= args.seconds <= 180 or not 1 <= args.passes <= 5:
        parser.error("Use 5–180 seconds per flight and 1–5 passes")
    if args.variant == "comparison" and not args.baseline_output:
        parser.error("Paired comparisons require --baseline-output")
    bundle = "com.alpineflight.prototype"
    run_id = str(uuid.uuid4())
    env = dict(os.environ)
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")

    def device(*command, check=True):
        result = subprocess.run(["xcrun", "devicectl", *command], env=env,
                                capture_output=True, text=True, timeout=60)
        if check and result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result

    if args.install:
        print("Installing signed test build", flush=True)
        device("device", "install", "app", "--device", args.device, str(args.install.resolve()))
    # CoreDevice's combined terminate-and-launch can race on a running iOS app.
    # End only Starflight, wait for its exit, then request a fresh launch.
    with tempfile.TemporaryDirectory(prefix="starflight-process-check-") as temporary:
        listing = Path(temporary) / "processes.json"
        def game_processes():
            device("device", "info", "processes", "--device", args.device,
                   "--json-output", str(listing))
            return [p["processIdentifier"] for p in json.loads(listing.read_text())["result"]["runningProcesses"]
                    if str(p.get("executable", "")).endswith("/AlpineFlight.app/AlpineFlight")]
        existing = game_processes()
        for pid in existing:
            device("device", "process", "terminate", "--device", args.device, "--pid", str(pid))
        for _ in range(20):
            if not game_processes():
                break
            time.sleep(0.25)
        else:
            raise RuntimeError("Starflight did not finish closing; no replacement run was started")
        lock_file = Path(temporary) / "lock.json"
        deadline = time.monotonic() + 180
        announced = False
        while time.monotonic() < deadline:
            device("device", "info", "lockState", "--device", args.device,
                   "--json-output", str(lock_file))
            if not json.loads(lock_file.read_text())["result"]["passcodeRequired"]:
                break
            if not announced:
                print("Unlock the device; the prepared run will start immediately", flush=True)
                announced = True
            time.sleep(1)
        else:
            raise RuntimeError("Device stayed locked; no run was started")
    child = {
        "STARFLIGHT_AETHER_VALIDATION": args.variant,
        "STARFLIGHT_AETHER_QUALITY": args.quality,
        "STARFLIGHT_AETHER_SECONDS": str(args.seconds),
        "STARFLIGHT_AETHER_PASSES": str(args.passes),
        "STARFLIGHT_AETHER_RUN_ID": run_id,
    }
    enabled = "YES" if args.variant == "candidate" else "NO"
    flags = ["--aether-release-check", "-aetherPlanetEnabled", "YES",
             "-aetherWorldDetailEnabled", "YES", "-aetherSurfaceEnabled", enabled]
    for world in ["Hoth", "Tatooine", "Endor"]:
        flags += [f"-aether{world}TerrainEnabled", enabled]
    print("Requested run:", run_id, flush=True)
    result = device("device", "process", "launch", "--device", args.device,
                    "--environment-variables", json.dumps(child), "--", bundle, *flags, check=False)
    if result.returncode:
        if "10004" not in result.stdout + result.stderr:
            raise RuntimeError(result.stdout + result.stderr)
        # CoreDevice can launch successfully but fail to return the process ID.
        # Accept nothing until a report with our exact fresh run ID arrives.
        print("Device did not return a process ID; verifying the requested report", flush=True)
    print(result.stdout.strip(), flush=True)
    name = ("candidate" if args.variant == "comparison" else args.variant) + ("-30" if args.quality == "balanced" else "-60")
    remote = "Documents/AetherValidation/" + name + ".json"
    deadline = time.monotonic() + 240 + (args.seconds + 9) * (3 * args.passes + 1) * (2 if args.variant == "comparison" else 1)
    previous = None
    with tempfile.TemporaryDirectory(prefix="starflight-aether-check-") as temporary:
        local = Path(temporary) / "report.json"
        baseline_marker = None
        while time.monotonic() < deadline:
            time.sleep(15)
            if args.variant == "comparison":
                baseline_file = Path(temporary) / "baseline.json"
                copied = device("device", "copy", "from", "--device", args.device,
                                "--source", remote.replace("candidate-", "baseline-"),
                                "--destination", str(baseline_file), "--domain-type", "appDataContainer",
                                "--domain-identifier", bundle, check=False)
                if not copied.returncode and baseline_file.exists():
                    baseline = json.loads(baseline_file.read_text())
                    if baseline.get("runID") == run_id:
                        args.baseline_output.parent.mkdir(parents=True, exist_ok=True)
                        args.baseline_output.write_text(json.dumps(baseline, indent=2) + "\n")
                        latest = baseline["segments"][-1]["name"] if baseline["segments"] else "preparation"
                        marker = (baseline["status"], latest)
                        if marker != baseline_marker:
                            print("baseline:", marker[0], "·", marker[1], flush=True)
                            baseline_marker = marker
                        if baseline["status"] not in ["running", "completed"]:
                            print("Baseline interrupted; no candidate will start", flush=True)
                            return 1
            copied = device("device", "copy", "from", "--device", args.device,
                            "--source", remote, "--destination", str(local),
                            "--domain-type", "appDataContainer", "--domain-identifier", bundle,
                            check=False)
            if copied.returncode or not local.exists():
                print("Waiting for first report (preparing or device unavailable)", flush=True)
                continue
            data = json.loads(local.read_text())
            if data.get("runID") != run_id:
                continue  # Never accept a report left by an earlier run.
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(data, indent=2) + "\n")
            segment = data["segments"][-1] if data["segments"] else None
            marker = (data["status"], segment["name"] if segment else "preparation")
            if marker != previous:
                print(f"{name}: {marker[0]} · {marker[1]}", flush=True)
                if segment:
                    print(f"  p95 callback {segment['p95CallbackMS']:.1f} ms; "
                          f"footprint {segment.get('endFootprintMB', 0):.1f} MB; "
                          f"thermal {segment['worstThermalState']}", flush=True)
                previous = marker
            if data["status"] != "running":
                print("Report:", args.output.resolve(), flush=True)
                return 0 if data["status"] == "completed" else 1
    raise TimeoutError("No completed report; inspect the saved partial report and device before retrying")


if __name__ == "__main__":
    raise SystemExit(main())
