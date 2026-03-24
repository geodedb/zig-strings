# ADR-001: SIMD Architecture with Runtime Detection and Scalar Fallbacks

## Status

Accepted

## Context

The strings library performs byte-level operations (case conversion, ASCII
detection, byte counting) that benefit from SIMD vectorisation on modern CPUs.
However, the library targets multiple architectures (x86_64, aarch64, wasm32,
generic) and must produce correct results on every target, including those
without vector extensions.

Key constraints:

- Zig's `@Vector` compiles to architecture-specific SIMD instructions
  automatically, but only when the target supports the required width.
- WASM and some embedded targets lack 128-bit or wider SIMD support.
- Users expect a single library artifact that works everywhere without
  conditional compilation at the call site.

## Decision

The SIMD module (`src/util/simd.zig`) uses **compile-time feature detection**
via `@typeInfo(std.Target).cpu` and `std.Target.Cpu.Feature` to select the
widest available vector width (256-bit, 128-bit, or scalar). Every SIMD
function has a scalar fallback that processes bytes one at a time when no
vector ISA is available.

The public API (`isAllAscii`, `toLowerAscii`, `toUpperAscii`, `countByte`,
`memcpySimd`) is identical regardless of backend. Callers never need to
check for SIMD availability.

The SIMD module is wired into higher-level modules (e.g., `case.zig`) via
build-system imports so that ASCII fast-paths are transparent to users.

## Consequences

**Positive:**

- Single API surface: consumers never branch on CPU features.
- Measured 7.6x throughput for `isAllAscii` and 48.5x for `countByte`
  versus scalar on x86_64 AVX2.
- Correctness is maintained in `ReleaseFast` because bounds checks use
  `@panic` instead of `std.debug.assert` (see GAP R1 closure).

**Negative:**

- The scalar fallback is measurably slower than hand-tuned scalar loops
  because it still sets up vector-width constants; this overhead is
  negligible in practice but is not zero.
- Compile-time detection cannot distinguish runtime CPU steppings that
  disable specific extensions (rare but possible). Runtime `cpuid`-based
  dispatch was considered too complex for the current scope.
