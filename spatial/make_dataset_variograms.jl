thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram
using Plots
gr()

const INDIR = ARGS[1]
const OUTDIR = ARGS[2]

@everywhere function makevariogram(indir, outdir, file)
    
    local decorrelationlength::Int64 = -1

    try

        # Load the dataset
        local datasetname::String = file[1:end - 4]
        print("$datasetname\n")
        
        local variogramfile::String = "$outdir/$datasetname.csv"
        local plotfile::String = "$outdir/$datasetname.png"
        local dataset::Array{Float64, 2} = readdlm("$indir/$file", '\t', Float64, '\n', header=true)[1]

        # Calculate the variogram
        local variogram = Variogram.variogram(dataset, 25)
        writedlm("$outdir/$datasetname.csv", variogram, ',')

        Plots.scatter(variogram[:,1], variogram[:,2])

        # Get the decorrelation length of the variogram
        decorrelationlength = Variogram.getdecorrelationlength(variogram, true)

        plotmarker = [[decorrelationlength, decorrelationlength] [0, maximum(variogram[:,2])]]
        Plots.plot!(plotmarker[:,1], plotmarker[:,2], linewidth=1, color="red", linestyle=:dot)

        Plots.png(plotfile)
    catch ex
        println(typeof(ex))
        showerror(STDOUT, ex)
        throw(ex)
    end

    return decorrelationlength
end

files = readdir(INDIR)

decorrelationlengths = pmap(f -> makevariogram(INDIR, OUTDIR, f), files, retry_delays=zeros(1000))

open("decorrelation_lengths.csv", "w") do f
    for i in 1:length(files)
        write(f, "$(files[i]),$(decorrelationlengths[i])\n")
    end
end
