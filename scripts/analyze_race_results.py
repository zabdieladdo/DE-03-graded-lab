"""Analyze flash-sale latency from the official race-test log."""

import math
import re
import statistics
import sys
from pathlib import Path


# Return the nearest-rank percentile of the observed sample.
def percentile(values, fraction):
    """Nearest-rank percentile."""
    ordered = sorted(values)
    return ordered[math.ceil(fraction * len(ordered)) - 1]


# Summarize observed attempt latency.
def summarize(label, values):
    print(
        f"{label:<12}"
        f"{len(values):>8}"
        f"{min(values):>12.2f}"
        f"{statistics.median(values):>12.2f}"
        f"{percentile(values, 0.95):>12.2f}"
        f"{max(values):>12.2f}"
    )


# Coordinate the command-line workflow and its validation.
def main():
    path = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else "evidence/22_race_test_verbose.txt"
    )

    content = path.read_text(encoding="utf-8")

    section = content.split(
        "Test 2 — flash sale:", 1
    )[1].split("Test 3 —", 1)[0]

    pattern = (
        r"\[\s*(\d+)\]\s+"
        r"success=(True|False|None)\s+"
        r"order_id=(\d+|None)\s+"
        r"([\d.]+)ms\s+"
        r"msg=(.*?)\s+err=(.*)$"
    )

    rows = re.findall(pattern, section, re.MULTILINE)

    if len(rows) != 400:
        raise SystemExit(
            f"Expected 400 attempts, found {len(rows)}"
        )

    successful = [
        float(r[3]) for r in rows if r[1] == "True"
    ]

    refused = [
        float(r[3]) for r in rows if r[1] == "False"
    ]

    errors = [
        r for r in rows if r[5].strip() != "''"
    ]

    successful_ids = [
        r[2] for r in rows if r[1] == "True"
    ]

    assert len({int(r[0]) for r in rows}) == 400
    assert len(successful) == 50
    assert len(refused) == 350
    assert len(errors) == 0
    assert len(set(successful_ids)) == 50
    assert all(oid != "None" for oid in successful_ids)

    assert all(
        r[2] == "None"
        and "out of stock" in r[4].lower()
        for r in rows
        if r[1] == "False"
    )

    wall_match = re.search(
        r"wall clock ([\d.]+)s",
        section,
    )

    if wall_match is None:
        raise SystemExit("Wall-clock measurement missing")

    wall = float(wall_match.group(1))

    print("=== Flash-sale performance analysis ===")
    print("Source:", path)
    print("Percentile method: nearest rank")
    print("Latency unit: milliseconds")
    print()

    print(
        f"{'Outcome':<12}"
        f"{'Calls':>8}"
        f"{'Min':>12}"
        f"{'Median':>12}"
        f"{'P95':>12}"
        f"{'Max':>12}"
    )

    summarize("All", successful + refused)
    summarize("Successful", successful)
    summarize("Refused", refused)

    print()
    print(f"Wall-clock time: {wall:.2f}s")
    print(f"Attempt throughput: {400 / wall:.2f}/s")
    print(f"Success throughput: {50 / wall:.2f}/s")
    print(f"Refusal throughput: {350 / wall:.2f}/s")
    print(f"Time below benchmark: {(1-wall/10)*100:.2f}%")
    print(f"Ten-second benchmark met: {wall <= 10}")
    print("Unique successful order IDs: 50")
    print("Refusal contract verification: PASS")
    print("Errors: 0")
    print("RESULT: Performance evidence verified")


if __name__ == "__main__":
    main()
