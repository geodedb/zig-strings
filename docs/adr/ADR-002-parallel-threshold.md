# ADR-002: Size-Based Thresholds for Parallel Operations

## Status

Accepted

## Context

The library provides parallel versions of string operations (`parallelCount`,
`parallelMap`, `parallelEditDistanceBatch`, `parallelFuzzySearch`) built on
the Spice fork/join framework. Spawning tasks has overhead: thread pool
dispatch, future allocation, and synchronisation cost. For small inputs, this
overhead exceeds the benefit of parallelism.

Benchmarks showed:

- `parallelMap` on 4 KB input ran 0.84x sequential (slower).
- `parallelCount` on 1 MB input ran 2.97x sequential (faster).
- Edit distance batches below 8 targets showed no parallel benefit.

## Decision

Each parallel operation defines a compile-time threshold below which it falls
back to the sequential implementation:

| Operation               | Threshold          | Rationale                          |
|-------------------------|--------------------|------------------------------------|
| `parallelCount`         | 4,096 bytes        | Fork/join overhead ~1 us           |
| `parallelMap`           | 65,536 bytes       | Higher per-element cost amortises  |
| `parallelEditDistanceBatch` | 8 targets     | O(n*m) per target; need enough work |
| `parallelFuzzySearch`   | 16 candidates      | Similar to edit distance           |

Thresholds are `const` values in `src/parallel.zig` and are documented in
the module header.

The fork/join recursion base case uses a separate, smaller threshold
(typically 2,048 bytes) to avoid over-splitting once parallelism is engaged.

## Consequences

**Positive:**

- Small inputs never pay parallelism overhead.
- Large inputs get measurable speedup (up to 3x on 4-core machines).
- Thresholds are easy to tune via constants; no runtime configuration needed.

**Negative:**

- Optimal thresholds are hardware-dependent. The chosen values target
  commodity x86_64 with 4+ cores; on 2-core systems or high-latency thread
  pools, the thresholds may be too low.
- There is no adaptive mechanism: the thresholds do not adjust based on
  observed latency. This was deemed acceptable for a string library (not a
  general task scheduler).
