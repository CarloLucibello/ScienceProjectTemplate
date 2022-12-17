# This is an example script demonstrating a pattern for parallel runs.#

using DrWatson
using ScienceProjectTemplate

using LinearAlgebra, Random, Statistics
using DataFrames, CSV
using BenchmarkTools
using OrderedCollections: OrderedDict
using ThreadsX

splitext(basename(@__FILE__))[1]

BLAS.set_num_threads(1) # set to 1 when using multiple threads (julia -t X)
# BLAS.set_num_threads(Sys.CPU_THREADS) # default value

function f_single_run(; N = 50,
                    α = 0.2,
                    η = 0.5,
                    λ = 0.1,
                    maxsteps = 1000,
                    nsamples = 1)
    
    if nsamples == 1
        # dummy function for demonstration purpose
        return (t = rand(1:100), E = rand())
    else 
        stats = ThreadsX.mapreduce(Stats(), 1:nsamples) do _  # remove ThreadsX. for single thread
            return (t = rand(1:100), E = rand())            
        end
        return (; nsamples, mean_with_err(stats)...)
    end
end


function parallel_run(;
        N = 40,
        α = 0.2,
        λ = [0.1:0.1:1.0;],
        resfile = savename((; N, α), "csv", digits=4),
        respath = datadir("raw", splitext(basename(@__FILE__))[1]), # defaults to data/raw/SCRIPTNAME 
        kws...)

    params_list = dict_list(OrderedDict(:N => N, :α=> α, :λ => λ))
    allres = Vector{Any}(undef, length(params_list))
    
    ThreadsX.foreach(enumerate(params_list)) do (i, p) # remove ThreadsX. for single threaded run
        res = f_single_run(; p..., kws...)
        allres[i] = NamedTuple(merge(p, res))
    end

    allres = DataFrame(allres)
    if resfile != "" && resfile !== nothing
        path = joinpath(respath, resfile)
        path = check_filename(path) # append a number if the file already exists
        CSV.write(path, allres)
    end
    return allres
end


## use @btime and @profview for profiling
# @btime f_single_run()
# @time parallel_run(N=40, nsamples=100, α=0.2)

