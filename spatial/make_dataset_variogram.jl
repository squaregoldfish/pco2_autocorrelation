thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram

const FILE = "datasets/64SA20071020.tsv"
#const FILE = "datasets/06AQ20091129.tsv"

dataset = readdlm(FILE, '\t', Float64, '\n', header=true)[1]
@time var = Variogram.variogram(dataset, 50)

writedlm("var.csv", var, ',')