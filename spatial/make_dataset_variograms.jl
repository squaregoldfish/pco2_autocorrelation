thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram
using Plots
gr()

const INDIR = ARGS[1]
const OUTDIR = ARGS[2]

@everywhere function makevariogram(indir, outdir, file)
    
    # Load the dataset
    local datasetname = file[1:end - 4]
    print("$datasetname\n")
    local dataset = readdlm("$indir/$file", '\t', Float64, '\n', header=true)[1]

    # Calculate the variogram
    @time local variogram = Variogram.variogram(dataset, 5)
    writedlm("$outdir/$datasetname.csv", variogram, ',')

    # Fit the variogram
    local fit = Variogram.fit(variogram)
    writedlm("$outdir/$datasetname.fit.csv", fit, ',')

    # Plot the variogram and fitted curve
    Plots.scatter(variogram[:,1], variogram[:,2], size=(1200,800))

    model(x, p) = p[1]*(1 - exp.(-x./p[2]))
    Plots.plot!(variogram[:,1], model(variogram[:,1], fit))
    Plots.png("$outdir/$datasetname.png")
end

files = readdir(INDIR)

@time pmap(files -> makevariogram(INDIR, OUTDIR, files), files)
