thisdir = dirname(@__FILE__())
any(path -> path==thisdir, LOAD_PATH) || push!(LOAD_PATH, thisdir)
using Variogram
using GeoStats


const FILE = "datasets/64SA20071020.tsv"
#const FILE = "datasets/06AQ20091129.tsv"

@time data = readtable(FILE, coordnames=[:lon,:lat], delim="\t")


