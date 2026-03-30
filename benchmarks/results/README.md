# Benchmark Results

This directory stores JSON benchmark results from `bench/scale_bench.zig` for tracking performance over time.

## File Format

Each file is a JSON document with version, timestamp, system info, and per-tier metrics:

```json
{
  "version": 1,
  "timestamp": "2026-03-30T12:00:00Z",
  "git_commit": "abc1234",
  "system": { "os": "linux", "arch": "x86_64" },
  "tiers": [
    {
      "name": "1KB",
      "input_bytes": 1024,
      "utf8_validate_mb_s": 12500.0,
      "normalize_nfc_mb_s": 850.0,
      "normalize_nfd_mb_s": 900.0,
      "case_lower_mb_s": 1200.0,
      "case_upper_mb_s": 1100.0,
      "grapheme_count_mb_s": 400.0,
      "count_mb_s": 3000.0,
      "search_mb_s": 5000.0
    }
  ]
}
```

All throughput metrics are in MB/s (higher is better).

## Naming Convention

- `baseline.json` -- the current accepted performance baseline
- `<short-sha>.json` -- results saved per commit via `make bench-save`

## Usage

```bash
make bench             # Run quick benchmarks (bench/main.zig)
make scale-bench       # Run scale benchmark, print results
make bench-save        # Run and save to benchmarks/results/<sha>.json
make bench-baseline    # Run and save as baseline
make bench-compare     # Run and compare against baseline
```

## Comparison

The comparison tool (`bench/compare.zig`) checks each metric against the baseline with a configurable regression threshold (default: 20%). Any throughput drop exceeding the threshold is flagged as FAIL.
