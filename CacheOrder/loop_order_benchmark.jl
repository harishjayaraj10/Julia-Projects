using Plots

function sum_fast(A)
    s = zero(eltype(A))
    @inbounds for j in axes(A, 2), i in axes(A, 1)
        s += A[i, j]
    end
    return s
end

function sum_slow(A)
    s = zero(eltype(A))
    @inbounds for i in axes(A, 1), j in axes(A, 2)
        s += A[i, j]
    end
    return s
end

function benchmark(f, A; reps = 5)
    acc = f(A)
    best = Inf
    for _ in 1:reps
        dt = @elapsed x = f(A)
        acc += x
        best = min(best, dt)
    end
    return best, acc
end

function run()
    sizes = [128, 256, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384]
    mb, tfast, tslow = Float64[], Float64[], Float64[]
    checksum = 0.0

    for n in sizes
        A = rand(n, n)
        tf, a1 = benchmark(sum_fast, A)
        ts, a2 = benchmark(sum_slow, A)
        checksum += a1 + a2

        push!(mb, n^2 * sizeof(eltype(A)) / 2^20)
        push!(tfast, tf * 1e3)
        push!(tslow, ts * 1e3)
        println("n=$n  $(round(mb[end], digits=2)) MB  fast $(round(tf*1e3, digits=3)) ms  slow $(round(ts*1e3, digits=3)) ms  $(round(ts/tf, digits=2))x")
    end

    checksum > 0 || error("empty benchmark")   # also stops the loops being optimized away
    return mb, tfast, tslow
end

mb, tfast, tslow = run()
ratio = tslow ./ tfast

# L2 cache of the performance cores (Apple M4 Pro), in MB
L2 = 16.0

cyan  = RGB(0.13, 0.83, 0.93)
amber = RGB(0.96, 0.62, 0.04)
ink   = RGB(0.80, 0.83, 0.88)
gridcol = RGB(0.17, 0.19, 0.23)

xl = (minimum(mb) * 0.75, maximum(mb) * 1.4)
style = (background_color = :black, background_color_inside = :black,
         foreground_color = ink, gridcolor = gridcol, gridalpha = 0.7, minorgrid = false,
         xscale = :log10, xlims = xl, tickfontsize = 9, guidefontsize = 11)

p1 = plot(mb, tfast; style...,
    label = "column-major (inner i)", color = cyan, lw = 3, marker = :circle, ms = 5, msw = 0,
    yscale = :log10, ylabel = "time (ms)",
    title = "Loop order and the CPU cache\n", titlefontsize = 15,
    legend = :topleft, legendfontsize = 10,
    background_color_legend = RGBA(0, 0, 0, 0), foreground_color_legend = ink)
plot!(p1, mb, tslow; label = "row-major (inner j)",
    color = amber, lw = 3, marker = :circle, ms = 5, msw = 0)
vline!(p1, [L2]; color = ink, ls = :dash, lw = 1, alpha = 0.4, label = "")
annotate!(p1, L2, maximum(tslow) * 0.6, text("L2 = 16 MB", 8, ink, :left, :top, rotation = 90))

p2 = plot(mb, ratio; style...,
    color = cyan, lw = 3, marker = :circle, ms = 5, msw = 0,
    fillrange = 1.0, fillcolor = cyan, fillalpha = 0.12,
    ylabel = "slowdown", xlabel = "matrix size (MB)", legend = false)
hline!(p2, [1.0]; color = ink, ls = :dash, lw = 1, alpha = 0.4, label = "")
vline!(p2, [L2]; color = ink, ls = :dash, lw = 1, alpha = 0.4, label = "")
imax = argmax(ratio)
annotate!(p2, mb[imax], ratio[imax],
    text("up to $(round(maximum(ratio), digits = 1))× slower", 9, cyan, :left, :bottom))

# data table as a third, text-only panel
fmt(x, w, d) = lpad(string(round(x, digits = d)), w)
rows = [string(lpad("MB", 8), lpad("fast(ms)", 9), lpad("slow(ms)", 9), lpad("ratio", 7))]
for i in eachindex(mb)
    push!(rows, string(fmt(mb[i], 8, 1), fmt(tfast[i], 9, 2),
                       fmt(tslow[i], 9, 2), fmt(ratio[i], 7, 1)))
end

p3 = plot(; framestyle = :none, legend = false, grid = false,
    xlims = (0, 1), ylims = (0, length(rows)),
    background_color = :black, background_color_inside = :black)
for (k, line) in enumerate(rows)
    y = length(rows) - k + 0.5
    col = k == 1 ? cyan : RGB(1.0, 1.0, 1.0)
    annotate!(p3, 0.02, y, text(line, 9, col, :left, "Courier"))
end

layout = @layout [[a{0.63h}; b] c{0.27w}]
plot(p1, p2, p3; layout = layout,
    background_color = :black, size = (1500, 950), dpi = 200,
    left_margin = 7Plots.mm, bottom_margin = 6Plots.mm, top_margin = 5Plots.mm)
savefig("cache_order.png")
