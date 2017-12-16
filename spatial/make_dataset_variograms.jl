thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram

const INDIR = ARGS[1]
const OUTDIR = ARGS[2]

@everywhere function makevariogram(indir, outdir, file)
    local datasetname = file[1:end - 4]
    print("$datasetname\n")
    local dataset = readdlm("$indir/$file", '\t', Float64, '\n', header=true)[1]
    @time local variogram = Variogram.variogram(dataset, 25)
    writedlm("$outdir/$datasetname.csv", variogram, ',')
end

files = readdir(INDIR)

@time pmap(files -> makevariogram(INDIR, OUTDIR, files), files)