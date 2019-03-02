try
    using ProgressMeter
catch
    import Pkg
    Pkg.add("ProgressMeter")
    using ProgressMeter
end



struct RideShare
    passengers_from::Vector{NTuple{2,Int}}
    passengers_to::Vector{NTuple{2,Int}}
    time_windows::Vector{NTuple{2,Int}}
    drivers::Vector{NTuple{2,Int}}
    speed::Float64
    gas::Float64
    rate::Float64
end

function get_initial_solution(rs::RideShare, prob=0.5)::Vector{Vector{Int}}
    driver_idxs = eachindex(rs.drivers)
    solution = [Int[] for x in driver_idxs]
    for x in eachindex(rs.passengers_from)
        if rand() > prob
            push!(solution[rand(driver_idxs)], x)
        else
            pushfirst!(solution[rand(driver_idxs)], x)
        end
    end
    solution
end


function iterate_solution(solution::Vector{Vector{Int}})
    new_solution = deepcopy(solution)
    possible_drivers = findall(x -> x > 0,  length.(solution))
    s_i = new_solution[rand(possible_drivers)]
    if rand(Bool) # swap
        s_j = new_solution[rand(possible_drivers)]
        pos_i = rand(eachindex(s_i))
        pos_j = rand(eachindex(s_j))
        s_i[pos_i], s_j[pos_j] = s_j[pos_j], s_i[pos_i]
    else # insert-delete
        s_j = rand(new_solution)
        pos_i = rand(eachindex(s_i));
        t = s_i[pos_i]
        deleteat!(s_i, pos_i)
        pushfirst!(s_j, t)
    end
    new_solution
end

dist_L1(a, b) = abs(b[1] - a[1]) + abs(b[2] - a[2])

function rideshare_optimality(rs::RideShare, solution::Vector{Vector{Int}})
    revenue = 0.0
    trips_completed = 0
    for x in eachindex(rs.drivers)
        t = 0.0
        driver_position = rs.drivers[x]
        for y in solution[x]
            curr_pass_from = rs.passengers_from[y]
            curr_pass_to = rs.passengers_to[y]
            current_time_window = rs.time_windows[y]
            revenue -= dist_L1(driver_position, curr_pass_from) * rs.gas
            t += dist_L1(driver_position, curr_pass_from) / rs.speed
            if t > current_time_window[2]
                driver_position = curr_pass_from
                continue
            end
            t = max(t, current_time_window[1])
            revenue += dist_L1(curr_pass_from, curr_pass_to) * rs.rate
            t += dist_L1(curr_pass_from, curr_pass_to) / rs.speed
            driver_position = curr_pass_to
            trips_completed += 1
        end
    end
    if revenue > 0.0
        revenue * (trips_completed / length(rs.passengers_to))
    else
        revenue * (1 - trips_completed / length(rs.passengers_to))
    end
end

rs_samples=[
    RideShare(
        [(15, 22),(23,13),(25,23),(6,30),(13,28),(24,26),(4,2),
         (30,23),(28,24),(28,18),(20,2),(28,7),(14,22),(20,21),
         (27,10),(8,7),(24,19),(24,6),(7,7),(7,22)], # passengers_from
        [(17,17),(22,10),(24,26),(3,27),(14,23),(22,28),(5,7),
         (27,22), (31,28),(23,23),(23,-3),(23,9),(19,18),(19,21),
         (30,6),(7,2),(29,23),(20,6),(10,10),(6,18)], # passengers_to
        [(91,101),(44,54),(22,32),(68,78),(108,118),(182,192),(19,29),
         (36,46),(183,193), (48,58),(209,219),(145,155),(141,151),(59,69),
         (236,246),(69,79),(177,187),(15,25),(145,155),(110,120)], # time_windows
        [(18,22),(9,20),(6,29),(30,28),(26,8)], #drivers
        1.0, #speed
        0.5, #gas
        2.5 # rate
        ),
    RideShare(
        [(4,30),(4,25),(21,1),(19,4),(3,14),(19,24),(29,17),
         (11,23),(17,29),(24,22)], # passengers_from
        [(11,36),(11,20),(22,6),(29,5),(-7,7),(20,31),(26,22),
         (10,23),(20,35),(24,28)], # passengers_to
        [(152,177),(254,279),(50,75),(255,280),(296,321),(76,101),
         (228,253),(134,159),(82,107),(201,226)], # time_windows
        [(27,1),(7,14),(20,11)], # drivers
        1.0, #speed
        0.5, #gas
        2.5 # rate
        )
    ]
