#!/usr/bin/env python3
"""Compare local Aether reports. Never turn callback cadence into GPU FPS claims."""
import argparse
import json
from pathlib import Path


def review(report):
    issues = []
    if report.get("status") != "completed":
        issues.append("run did not complete: " + report.get("status", "missing status"))
    flights = [s for s in report["segments"] if " flight" in s["name"]]
    fps = report["targetFPS"]
    for sample in flights:
        label = sample["name"]
        if sample["outcome"] != "flying" or sample["callbackCount"] < 30:
            issues.append(label + ": missing sustained flight sample")
        if sample["p95CallbackMS"] > (40 if fps == 30 else 20):
            issues.append(label + ": callback p95 above review budget")
        if sample["overBudgetCallbacks"] / max(1, sample["callbackCount"]) > 0.05:
            issues.append(label + ": more than 5% late callbacks")
        if sample["p95UpdateWorkMS"] > (20 if fps == 30 else 10):
            issues.append(label + ": CPU update p95 above review budget")
    for sample in report["segments"]:
        if sample.get("peakFootprintMB") is None:
            issues.append(sample["name"] + ": footprint unavailable")
        elif sample["peakFootprintMB"] > 600:
            issues.append(sample["name"] + ": footprint above 600 MiB review budget")
        if sample["worstThermalState"] >= 2 or sample["memoryWarnings"]:
            issues.append(sample["name"] + ": thermal or memory pressure")
    orbits = [s for s in report["segments"] if " orbit" in s["name"]]
    if len(orbits) >= 2 and orbits[-1].get("endFootprintMB") is not None and orbits[0].get("endFootprintMB") is not None:
        if orbits[-1]["endFootprintMB"] - orbits[0]["endFootprintMB"] > 50:
            issues.append("warm orbit footprint grew by more than 50 MiB")
    events = report.get("events", {})
    # Parent-view tasks may begin after synchronous attachment. Review the sum
    # as a conservative upper bound rather than pretending the wait is total launch time.
    preparation = events.get("startupUntilReadySeconds", float("inf")) + events.get("worldConstructionSeconds", 0)
    if preparation > 60:
        issues.append("preparation upper bound above 60 seconds or missing")
    if not flights:
        issues.append("no flight samples")
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reports = [json.loads(path.read_text()) for path in [args.baseline, args.candidate]]
    for key in ["model", "os", "targetFPS", "physicalMemoryMB", "version", "build", "lowPowerMode"]:
        if reports[0].get(key) != reports[1].get(key):
            parser.error("Comparison configuration differs: " + key)
    if not reports[0]["variant"].startswith("baseline") or not reports[1]["variant"].startswith("candidate"):
        parser.error("Expected baseline followed by candidate")
    lines = ["# Aether physical-device comparison", "", f"Model: {reports[0]['model']}; {reports[0]['os']}; target {reports[0]['targetFPS']} Hz.",
             "", "Intervals below measure game callbacks, not actual GPU-presented frames.", "",
             "| Variant / window | Seconds | Callback p95 ms | CPU update p95 ms | Peak MiB | Thermal* | Outcome |",
             "|---|---:|---:|---:|---:|---:|---|"]
    for report in reports:
        for sample in report["segments"]:
            memory = sample.get("peakFootprintMB")
            memory_text = f"{memory:.1f}" if memory is not None else "Unavailable"
            lines.append(f"| {report['variant']} / {sample['name']} | {sample['seconds']:.1f} | "
                         f"{sample['p95CallbackMS']:.0f} | {sample['p95UpdateWorkMS']:.0f} | "
                         f"{memory_text} | {sample['worstThermalState']} | {sample['outcome']} |")
    lines += ["", "*Thermal: 0 nominal, 1 fair, 2 serious, 3 critical. Peaks include GPU/driver allocations charged to the app.", ""]
    for report in reports:
        issues = review(report)
        lines += ["## " + report["variant"], "", "Local review: " + ("REVISE" if issues else "Callback/resource checks passed"), ""]
        lines.extend("- " + issue for issue in issues)
        lines += ["", "Events: `" + json.dumps(report.get("events", {}), sort_keys=True) + "`", ""]
    lines += ["## Release boundary", "", "This automated report cannot approve release by itself. Physical iPad testing, GPU presentation evidence, visual/gameplay review and longer thermal sessions remain separate gates."]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")
    print(args.output.resolve())


if __name__ == "__main__":
    main()
