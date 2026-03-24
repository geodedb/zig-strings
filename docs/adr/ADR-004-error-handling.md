# ADR-004: Checked Arithmetic for Size Computations

## Status

Accepted

## Context

String operations that compute output sizes -- `join`, `repeat`, `concat`,
`padLeft`, `padRight`, `replaceN` -- multiply or add user-controlled values
(string lengths, repeat counts, padding widths). On 64-bit targets, integer
overflow in `usize` arithmetic wraps silently in release builds, which can
cause undersized allocations followed by out-of-bounds writes.

Example: `repeat(str, n)` computes `str.len * n`. If the product overflows,
the allocated buffer is smaller than expected, and the subsequent `@memcpy`
loop writes past the end.

## Decision

All size computations that combine user-controlled inputs use Zig's checked
arithmetic functions:

- `std.math.mul(usize, a, b) catch return error.Overflow`
- `std.math.add(usize, a, b) catch return error.Overflow`

These return an error on overflow instead of wrapping. The error propagates
to the caller as `error.Overflow`, which is part of the standard
`Allocator.Error` union.

Functions using this pattern:

| Function    | File                      | Checked Operation          |
|-------------|---------------------------|----------------------------|
| `join`      | `src/ops/manipulation.zig` | `mul` for separator total  |
| `repeat`    | `src/ops/manipulation.zig` | `mul` for total length     |
| `concat`    | `src/ops/manipulation.zig` | `add` for running total    |
| `padLeft`   | `src/ops/manipulation.zig` | `mul` + `add` for padding  |
| `padRight`  | `src/ops/manipulation.zig` | `mul` + `add` for padding  |
| `replaceN`  | `src/ops/manipulation.zig` | `mul` + `add` for new size |

## Consequences

**Positive:**

- Overflow is impossible: callers get a clean error instead of memory
  corruption or undefined behaviour.
- Works identically in Debug and ReleaseFast builds.
- No performance overhead for non-overflowing inputs (the check is a single
  branch after the multiplication).

**Negative:**

- Callers must handle `error.Overflow` in addition to `error.OutOfMemory`.
  This is a minor API ergonomics cost.
- The checked functions are slightly slower than raw `*` / `+` due to the
  overflow detection, but the cost is negligible compared to the allocation
  and copy that follow.
