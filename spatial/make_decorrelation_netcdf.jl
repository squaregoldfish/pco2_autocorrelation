using NCDatasets

const SOCAT_FILE = "SOCATv5_all.tsv"::String
const DECORRELATION_LENGTHS_FILE = "decorrelation_lengths.csv"::String
const CELL_SIZE = 2.5::Float64

# Get the longitudes
function getlongitudes()
    local longitudes::Array{Float64, 1} = Array{Float64, 1}(convert(Int64, 360 / CELL_SIZE))
    for i in 1:length(longitudes)
        longitudes[i] = i * CELL_SIZE - (CELL_SIZE / 2)
    end

    return longitudes
end

# Get the latitudes
function getlatitudes()
    local latitudes::Array{Float64, 1} = Array{Float64, 1}(convert(Int64, 180 / CELL_SIZE))
    for i in 1:length(latitudes)
        latitudes[i] = i * CELL_SIZE - (CELL_SIZE / 2) - 90
    end

    return latitudes
end

# Calculate the cell indices from a longitude and latitude
function getcellindex(longitude::Float64, latitude::Float64)
    local loncell::Int64 = floor(longitude / CELL_SIZE) + 1
    local latcell::Int64 = floor((latitude + 90) / CELL_SIZE) + 1

    if loncell == 145
        loncell = 1
    end

    return loncell, latcell
end

# Add the specified decorrelation length to cells specified
function assigndatasetcells(totals::Array{Int64, 2}, counts::Array{Int64, 2}, cellsindataset::Array{Bool, 2}, decorrelationlength::Int64)
    if decorrelationlength != -1
        for lon in 1:size(cellsindataset)[1]
            for lat in 1:size(cellsindataset)[2]

                if cellsindataset[lon, lat]
                    totals[lon, lat] = totals[lon, lat] + decorrelationlength
                    counts[lon, lat] = counts[lon, lat] + 1
                end
            end
        end
    end
end

# Main function
function run()

    # Initialise data structures
    local totals::Array{Int64, 2} = zeros(convert(Int64, 360 / CELL_SIZE), convert(Int64, 180 / CELL_SIZE))
    local counts::Array{Int64, 2} = zeros(convert(Int64, 360 / CELL_SIZE), convert(Int64, 180 / CELL_SIZE))

    # Read in the decorrelation lengths
    local decorrelationlengths::Array{String, 2} = readdlm(DECORRELATION_LENGTHS_FILE, ',', String, '\n', header=false)

    local currentdataset::String = ""
    local currentdecorrelationlength::Int64 = -1
    local datasetcells::Array{Bool, 2} = falses(convert(Int64, 360 / CELL_SIZE), convert(Int64, 180 / CELL_SIZE))

    local socatchan::IOStream = open(SOCAT_FILE)

    currentline = readline(socatchan)
    local linecount = 1

    # Loop until the end of the file
    while length(currentline) > 0

        fields = split(currentline, "\t")
        dataset = fields[1]

        if (dataset != currentdataset)
            if !isnull(currentdataset)
                assigndatasetcells(totals, counts, datasetcells, currentdecorrelationlength)
            end

            currentdataset = dataset
            rowsearch = find(decorrelationlengths[:,1] .== "$(dataset).tsv")
            if size(rowsearch) == 0 || size(rowsearch)[1] == 0
                decorrelationrow = -1
            else
                decorrelationrow = rowsearch[1]
            end

            if decorrelationrow != -1
                currentdecorrelationlength = parse(Int, decorrelationlengths[decorrelationrow[1], 2])
            else
                # The data set doesn't have a decorrelation length,
                # so we'll ignore it later on
                currentdecorrelationlength = -1
            end

            datasetcells = falses(convert(Int64, 360 / CELL_SIZE), convert(Int64, 180 / CELL_SIZE))

            print("\033[1K\r$dataset ($linecount)")
        end

        lon = parse(Float64, fields[11])
        lat = parse(Float64, fields[12])

        cell = getcellindex(lon, lat)
        datasetcells[cell[1], cell[2]] = true

        currentline = readline(socatchan)
        linecount += 1
    end

    if !isnull(currentdataset)
        assigndatasetcells(totals, counts, datasetcells, currentdecorrelationlength)
    end

    # Calculate the mean decorrelation lengths and write them to disk
    print("\033[1K\rWriting to disk...")
    local meandecorrelationlengths::Array{Float64, 2} = fill(NaN, (convert(Int64, 360 / CELL_SIZE), convert(Int64, 180 / CELL_SIZE)))
    for i in 1:convert(Int64, 360 / CELL_SIZE)
        for j in 1:convert(Int64, 180 / CELL_SIZE)
            if counts[i, j] > 0
                meandecorrelationlengths[i, j] = totals[i, j] / counts[i, j]
            end
        end
    end

    ds::Dataset = Dataset("mean_decorrelation_lengths.nc", "c")

    defDim(ds, "longitude", convert(Int64, 360 / CELL_SIZE))
    defDim(ds, "latitude", convert(Int64, 180 / CELL_SIZE))

    local lonvar::NCDatasets.CFVariable = defVar(ds, "longitude", Float32, ["longitude"])
    lonvar.attrib["units"] = "degrees_east"
    local latvar::NCDatasets.CFVariable = defVar(ds, "latitude", Float32, ["latitude"])
    latvar.attrib["units"] = "degrees_north"

    local meanvar::NCDatasets.CFVariable = defVar(ds, "decorrelation_lengths", Float64, ["longitude", "latitude"], fillvalue=-999.9)
    local totalvar::NCDatasets.CFVariable = defVar(ds, "totals", Float64, ["longitude", "latitude"], fillvalue=-999.9)
    local countvar::NCDatasets.CFVariable = defVar(ds, "counts", Float64, ["longitude", "latitude"], fillvalue=-999.9)

    lonvar[:] = getlongitudes()
    latvar[:] = getlatitudes()
    meanvar[:, :] = meandecorrelationlengths
    totalvar[:, :] = totals
    countvar[:, :] = counts

    close(ds)

    println()
end

run()