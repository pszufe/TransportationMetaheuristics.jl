include("common.jl")

# bkamins: this function mostly reuses what is below; to be discussed
function calibrate(rs::RideShare, initial_solution::Vector{Vector{Int}})
    temperature = 1000.0
    iterations_per_temp = 1000
    cooling = 0.6
    accept_prob = 1.0
    current_solution = deepcopy(initial_solution)
    i, accepted, total, k = 0, 0.0, 0, 1

    current_score = rideshare_optimality(rs, initial_solution)

    # bkamins: I have change changed the logic of calculation of accept_prob
    # to make it more consistent
    while accept_prob > 0.6
        if i > iterations_per_temp
            accept_prob = total == 0 ? 1.0 : accepted / total
            temperature *= cooling
            accepted, total, i = 0.0, 0, 0
        end
        s_new = iterate_solution(current_solution)
        score_new = rideshare_optimality(rs, s_new)
        if score_new > current_score
            current_score = score_new
            current_solution = s_new
        else
            delta_score = score_new - current_score
            prob = 1 - exp(delta_score / (k * temperature))
            accepted += prob
            total = total + 1
            if prob < rand()
                current_score = score_new
                current_solution = s_new
            end
        end
        i = i + 1
    end
    println("Calibrated Temperature $temperature")
    temperature
end

function simulated_annealing(rs::RideShare;
                             final_temp=0.001, max_iterations=1000,
                             max_accept=2, alpha=0.90, threshold=1000)
    progress = Float64[]
    temp_progress = Float64[]
    current_progress = Float64[]
    solution = get_initial_solution(rs)
    current_temp = calibrate(rs, solution)
    current = rideshare_optimality(rs, solution)
    best = current
    best_schedule = solution
    i, accept, k = 0, 0.0, 1

    println("Initial Solution:")
    foreach((x, s) -> println("Driver #$x : $s"), enumerate(solution))
    println("Initial revenue: $current")
    waitbar = Progress(max_iterations, 1)
    while current_temp > final_temp && i < max_iterations && current < threshold
        if accept >= max_accept
            accept = 0
            current_temp *= alpha
        end
        next_schedule = iterate_solution(solution)
        next = rideshare_optimality(rs,next_schedule)
        if next > current
            accept += 1
            solution, current = next_schedule, next
        else
            delta = next - current
            if exp(delta / (k * current_temp)) > rand()
                accept += 1
                solution, current = next_schedule, next
            end
        end
        if current > best
            best, best_schedule = current, solution
        end
        i += 1
        push!(progress, best)
        push!(temp_progress, current_temp)
        push!(current_progress, current)
        next!(waitbar)
    end

    println("Iterations: $i")
    println("Best Solution")
    foreach((x, s) -> println("Driver #$x : $s"), enumerate(best_schedule))
    println("Best revenue: $best")
    return (current_progress, best_schedule)
end

using Random
Random.seed!(1234)

res = simulated_annealing(rs_samples[1]; max_iterations=10000, alpha=0.95)
res = simulated_annealing(rs_samples[2]; max_iterations=10000, alpha=0.95)
