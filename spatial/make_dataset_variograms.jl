thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram
using Plots
gr()

const INDIR = ARGS[1]
const OUTDIR = ARGS[2]

@everywhere function makevariogram(indir, outdir, file)
    
    # Load the dataset
    local datasetname::String = file[1:end - 4]
    print("$datasetname\n")
    
    local variogramfile::String = "$outdir/$datasetname.csv"
    local plotfile::String = "$outdir/$datasetname.png"

    # Don't overwrite an existing variogram
    local alreadycalculated::Bool = false
    if isfile(variogramfile) && stat(variogramfile).size > 0 && isfile(plotfile) && stat(plotfile).size > 0
        alreadycalculated = true
    end

    if !alreadycalculated

        local readcount::Int64 = 0
        local dataset::Array{Float64, 2} = readdlm("$indir/$file", '\t', Float64, '\n', header=true)[1]

        # Calculate the variogram
        local variogram = Variogram.variogram(dataset, 5)
        writedlm("$outdir/$datasetname.csv", variogram, ',')

        # Fit the variogram
        #local fit = Variogram.fit(variogram)
        #writedlm("$outdir/$datasetname.fit.csv", fit, ',')

        #local polyfit = Variogram.polyfit(variogram)
        #writedlm("$outdir/$datasetname.polyfit.csv", polyfit, ',')

        # Plot the variogram and fitted curve
        Plots.scatter(variogram[:,1], variogram[:,2], size=(1200,800))

        #model(x, p) = p[1]*(1 - exp.(-x./p[2]))
        #Plots.plot!(variogram[:,1], model(variogram[:,1], fit))

        #polymodel(x, p) = p[1] + p[2]x + p[3]x.^2 + p[4]x.^3 + p[5]x.^4 + p[6]x.^5 + p[7]x.^6 + p[8]x.^7 + p[9]x.^8 + p[10]x.^9 + p[11]x.^10
        #Plots.plot!(variogram[:,1], polymodel(variogram[:,1], polyfit))

        Plots.png("$outdir/$datasetname.png")
    end
end

files = readdir(INDIR)

pmap(f -> makevariogram(INDIR, OUTDIR, f), files)
