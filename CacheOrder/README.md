# Cache order

Julia stores matrices **column-major** — `A[i, j]` sits next to `A[i+1, j]` in memory.
The CPU also moves memory in fixed **cache lines** (128 bytes here, i.e. 16 `Float64`s),
not one element at a time. Together, those two facts make loop order matter when you
sum a matrix:

- **inner loop `i`** (column-major) walks memory in order → every cache line it pulls
  in gets fully used.
- **inner loop `j`** (row-major) jumps a whole column each step → it touches a new
  cache line almost every time and uses only one value from it.

Same array, same additions — only the loop order changes. This benchmarks both orders
on matrices from ~0.1 MB up to a 2 GB matrix.

![result](cache_order.png)

## What it shows

- While the matrix fits in cache, order barely matters (~1×) — the "wasteful" loop
  still finds its data in fast cache.
- Once the matrix grows past the ~16 MB L2 cache, the row-major loop starts missing on
  nearly every access and has to go to main memory → up to ~5.8× slower here.
- The gap then plateaus: once the matrix is far larger than any cache, the row-major
  loop pays a cache miss per access — a roughly fixed cost per element — so both orders
  scale the same way with size and their ratio settles to a near-constant factor.

## Hardware

Measured on an **Apple M4 Pro** (48 GB RAM, 128-byte cache lines; performance cores
have 128 KB L1d and 16 MB L2). The exact numbers — where the cliff sits and how big the
plateau is — depend on the machine's cache sizes, so expect different values on other
CPUs.

## Run

```bash
julia --project=. loop_order_benchmark.jl
```

Writes `cache_order.png`.
