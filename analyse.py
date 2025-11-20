#!/usr/bin/env python3
import os
import sys
import csv
import statistics

def main(root_dir: str) -> None:
    # Iterate over each run directory (e.g. 1763626965, 1763656510, ...)
    for run_name in sorted(os.listdir(root_dir)):
        run_path = os.path.join(root_dir, run_name)
        if not os.path.isdir(run_path):
            continue  # skip files

        # key: (model_name, metric) -> list of actual values
        stats = {}

        # Read all CSV files inside this run directory
        for fname in os.listdir(run_path):
            if not fname.endswith(".csv"):
                continue

            fpath = os.path.join(run_path, fname)
            with open(fpath, newline="") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    model = row["name"]
                    metric = row["metric"]

                    # Parse the "actual" column as float
                    try:
                        actual = float(row["actual"])
                    except ValueError:
                        # Skip rows that don't have a valid numeric actual
                        continue

                    key = (model, metric)
                    stats.setdefault(key, []).append(actual)

        # Now compute statistics for each (model, metric) within this run
        for (model, metric), values in sorted(stats.items()):
            avg = statistics.mean(values)
            median = statistics.median(values)
            maxv = max(values)
            minv = min(values)
            # population stddev; change to statistics.stdev for sample stddev
            std = statistics.pstdev(values) if len(values) > 1 else 0.0

            print(
                f"{model} - {metric} - {run_name} - "
                f"avg {avg:.2f}, std {std:.2f}, median {median:.2f}, "
                f"max {maxv:.2f}, min {minv:.2f}"
            )

if __name__ == "__main__":
    # Usage: python script.py [root_dir]
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    main(root)
