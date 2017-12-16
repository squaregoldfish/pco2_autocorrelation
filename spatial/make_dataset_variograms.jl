thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram
using Plots
gr()

const INDIR = ARGS[1]
const OUTDIR = ARGS[2]

for file in readdir(INDIR)

    datasetname = file[1:end - 4]
    dataset = readdlm("$INDIR/$file", '\t', Float64, '\n', header=true)[1]
    variogram = Variogram.variogram(dataset, 25)
    writedlm("$OUTDIR/$datasetname.csv", variogram, ',')
    scatter(variogram[:,1], variogram[:,2], size=(1200,800))
    savefig("$OUTDIR/$datasetname.png")
end





