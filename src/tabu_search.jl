# bkamins: we might keep here the code as previously defined
try
    using ProgressMeter
catch
    import Pkg
    Pkg.add("ProgressMeter")
    using ProgressMeter
end

include("common.jl")

function tabu_search(rs::RideShare; tabu_tenure=10, max_iterations=100)
    initial_solution = get_initial_solution(rs)
    initial_cost = rideshare_optimality(rs, initial_solution)

    # If you'd like to start with predetermined solution
    # comment the previous line and intialize the following paratmeters:
    # initial_solution = [1,2,4,3,5]
    # initial_cost = 35
    # solutions_list = [initial_cost]

    println("---------------------------------------------------------------")
    println("-------- INITIAL SOLUTION: $initial_solution")
    println("-------- INITIAL COST: $initial_cost")
    println("----------------------------------------------------------------")

    num_nodes = mapreduce(length, +, initial_solution, init=length(initial_solution))

    # Tabu list intialization to zero.
    tabu_list = zeros(Int,num_nodes,num_nodes)

    current_solution = initial_solution # The current solution is the intial solution.
    best_solution = initial_solution    # The best solution is the intial solution.
    best_cost = initial_cost            # The min. cost is the cost of the intial solution.
    solutions_list = Float64[]

    for i in 1:max_iterations
        println("\n--------------- ITERATION $i ---------------")
        # Obtaining best neighboring solution.
        best_neighbourhood_solution, best_neighbourhood_cost =
            get_neighbourhood!(rs,current_solution, best_cost, tabu_list,
                               tabu_tenure, solutions_list)

        # The obtained neighboring solution is the current solution.
        current_solution = best_neighbourhood_solution

    	# Comparing if it's the best solution so far.
        if (best_neighbourhood_cost > best_cost)
            best_solution = best_neighbourhood_solution
            best_cost = best_neighbourhood_cost
            # bkamins: why is this commented out?, append! would be better
            #solutions_list = [solutions_list best_neighbourhood_cost]
        end
    end

    println("-----------------------------------------------------------------")
    println("------- THE BEST SOLUTION OBTAINED IN $max_iterations ITERATIONS:")
    foreach(println, best_solution)
    println("-------- COST OF THE BEST SOLUTION: $best_cost")
    println("-------- THE LIST OF SOLUTIONS: $solutions_list")
    println("--------------------------------------------------------------------")
    (solutions_list, best_solution)
end

```
Function that obtains the best neighboring solution by realzing a set of
modifications in the current solution.
Generate different neighboring solutions by swapping and keep the solution with min. cost.
Input parameters:
  - current_solution: current solution.
  - best_cost: cost of the best solution obatined so far.
  - tabu_tenure: number of iterations a swapping will be in the tabu list.
  - tabu_list: Tabu list.
  - cost_matrix: Mcost matrix.
Output parameters:
  - best_neighbourhood_solution: best neighboring solution obtained.
  - best_neighbourhood_cost: cost of the best neighboring solution obatined.
Mutates the `tabu_list` and `solutions_list`.
```
function get_neighbourhood!(rs::RideShare, current_solution, best_cost, tabu_list,
                            tabu_tenure, solutions_list)
    println("get_neighbourhood tabu_list= $tabu_list")
    println("\nTHE BEST KNOWN SOLUTION COST: $best_cost")
    println("\nCURRENT SOLUTION $current_solution ")

    push!(solutions_list,best_cost)

    best_neighbourhood_solution = current_solution
    best_neighbourhood_cost = 0.0
    best_node1, best_node2 = 0, 0

    min_cost = 0.0
    node_count = length(current_solution)

    for y in 1:node_count
        for i in 1:length(current_solution[y])
            # Obtaining all possible neighboring solutions.
            for j in (i+1):length(current_solution[y])
                neighbourhood_solution = deepcopy(current_solution)
                if rand() > 0.6
                    temp = neighbourhood_solution[y][i]
                    neighbourhood_solution[y][i] = neighbourhood_solution[y][j]
                    neighbourhood_solution[y][j] = temp
                else
                    next = min(y + 1, node_count)
                    index1 = min(i, length(neighbourhood_solution[y]))
                    index2 = min(j, length(neighbourhood_solution[next]))

                    temp = neighbourhood_solution[y][index1]
                    neighbourhood_solution[y][index1] = neighbourhood_solution[next][index2]
                    neighbourhood_solution[next][index2] = temp
                end


                println("- CANDIDATE neighbourhood SOLUTION: $neighbourhood_solution")

                # Checking that the swap is not in the tabu.
                neighbourhood_cost = rideshare_optimality(rs, neighbourhood_solution)
                # Penalizing the moves that are more frequent for diversifying the search.
                #println(neighbourhood_solution[y][i]," ",neighbourhood_solution[y][j]," ",size(tabu_list))
                swapping_frequency = get_swapping_frequency(neighbourhood_solution[y][i],
                                                            neighbourhood_solution[y][j],
                                                            tabu_list)
                diversification_cost = neighbourhood_cost + swapping_frequency

                if !is_tabu_solution(neighbourhood_solution[y][i],neighbourhood_solution[y][j],tabu_list)
                    # Is not a tabued solution.

                    println("--- COST: $neighbourhood_cost + $swapping_frequency = $diversification_cost \n")

                    if (min_cost == 0) || (diversification_cost > min_cost)
                        # best solution obatined so far
                        min_cost = diversification_cost
                        best_neighbourhood_solution = neighbourhood_solution
                        best_neighbourhood_cost = neighbourhood_cost
                        best_node1 = neighbourhood_solution[y][i]
                        best_node2 = neighbourhood_solution[y][j]
                    end
                else
                    # Is a tabued solution:
                    # To avoid stagnation, apply asipration criteria
                    # If the cost of the solution is less that the cost of best solution obatined so far, accept this solution
                    if (diversification_cost > best_cost)
                        # best solution obatined so far.
                        min_cost = diversification_cost
                        best_neighbourhood_solution = neighbourhood_solution
                        best_neighbourhood_cost = neighbourhood_cost
                        best_node1 = neighbourhood_solution[y][i]
                        best_node2 = neighbourhood_solution[y][j]
                        println("- TABU SOLUTION ALLOWED - ASPIRATION CRITERIA: $neighbourhood_solution")
                        println("- ALLOWED TABU COST: $neighbourhood_cost + $swapping_frequency = $diversification_cost")
                    else
                        # Tabued solution is not permited.
                        println("- IS A TABU neighbourhood SOLUTION: $neighbourhood_solution")
                        println("--- TABU COST: $neighbourhood_cost + $swapping_frequency = $diversification_cost")
                    end
                end
            end
        end
    end

    # afterm obtaining the best neighbourhood solution, update the tabu list
    replace!(x -> x > 0 ? x - 1 : x, tabu_list)
    println("\nADD ($best_node1,$best_node2) TO TABU LIST: ")
    if best_node1 > 0 && best_node2 > 0
        add_swapping_tabu_list!(best_node1,best_node2,tabu_list,tabu_tenure)
    end

    println("tabu_list= $tabu_list")
    (best_neighbourhood_solution, best_neighbourhood_cost)
end

```
Adds a swapping to the tabu list controlling the frequency of this swapp.
Input parameters:
  - node1, node2: swapping nodes.
  - tabu_list: tabu list.
  - tabu_tenure: tabu tenure.
```
function add_swapping_tabu_list!(node1, node2, tabu_list, tabu_tenure)
    tabu_list[min(node1,node2),max(node1,node2)] = tabu_tenure
    tabu_list[max(node1,node2),min(node1,node2)] += 1
end

```
Checks the solution is listed as tabued.
Input parameters:
  - node1, node2: swapping nodes.
  - tabu_list: tabu list.
```
is_tabu_solution(node1, node2, tabu_list) =
    tabu_list[min(node1, node2), max(node1, node2)] > 0


```
Gets the swapping frequency
Input parameters:
  - node1, node2: swapping nodes.
  - tabu_list: tabu list.
```
get_swapping_frequency(node1, node2, tabu_list) =
    tabu_list[max(node1, node2), min(node1, node2)]


```
Function to obtain the nearest nodes to the current one that has not been visited before
Input parameters:
  - node_cost_list: vector of the costs of the current node.
  - initial_path: path obatined so far.
Output Parameters:
  - nearest_node: nearest node.
  - min_cost: cost to go to the nearest node.
```
function get_nearest_node(node_cost_list, initial_path)

    num_nodes = length(node_cost_list) # Number of nodes.
    visited_nodes = Set{Int}(initial_path)
    min_cost = 0 # Minimum cost.
    nearest_node = 0 # Selected node.

    for node=1:num_nodes
        # Checking that we have not visited this node before.
        if node in visited_nodes
            # Not visted node
            if min_cost == 0 || node_cost_list(node) < min_cost
                # The nearest node so far.
                min_cost = node_cost_list(node)
                push!(visited_nodes, node)
                nearest_node = node
            end
        end
    end
    (nearest_node, min_cost)
end


using Random
#Random.seed!(0)

res = tabu_search(rs_samples[1]; max_iterations=1000,tabu_tenure=10)
res = tabu_search(rs_samples[2]; max_iterations=20)
