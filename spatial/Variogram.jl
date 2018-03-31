module Variogram
using Distances
using SmoothingSplines
using Plots


export variogram
export getdecorrelationlength

"""
    Utility type to collect values for a semivariogram bin
"""
type BuildBin
    sumofsquares::Float64
    entries::Int

    BuildBin() = new(0.0, 0)
end

"""
   Add a value to a mean
"""
function add(x::BuildBin, value::Float64)
    x.sumofsquares += value^2
    x.entries += 1
end

"""
   Calculate the final value of a mean
"""
function mean(x::BuildBin)
    result::Float64 = NaN

    if x.entries > 0
        result = x.sumofsquares / (2 * x.entries)

    end

    return result
end

"""
    Computes a variogram for a set of geographical points.

    The passed in `pointdata` must be an array in which is row
    contains `lon`, `lat`, `value`.

    `binsize` defines the size of the bins in the variogram,
    in kilometres.


"""
function variogram(pointdata::Array{Float64,2}, binsize::Int64)
    
    @assert length(pointdata[1, :]) == 3 "Point data must contain 3 columns"
    @assert binsize > 0 "Bin size must be greater than zero"

    # Create the array of bins.
    # The Earth is 40,075km in diameter, so the maximum
    # distance between points is 20,037.5km.
    # So the number of bins is ceil(20,037.5 / binsize).
    bins::Array{BuildBin} = [BuildBin() for i = 1:ceil(20037.5 / binsize)]
    bin_distances::Array{Int64} = collect(0:binsize:20037.5)

    # Go through every pair of points, and
    # add the difference in value between each pair
    # to the appropriate bin
    npoints::Int64 = size(pointdata)[1]

    largest_bin::Int64 = 0

    for i in 1:npoints - 1

        point1::Array{Float64} = pointdata[i, 1:2]
        value1::Float64 = pointdata[i, 3]

        for j in i:npoints
            
            point2::Array{Float64} = pointdata[j, 1:2]

            distance::Float64 = evaluate(Distances.Haversine(6371), point1, point2)
            bin::Int64 = Int64(floor(distance / binsize)) + 1
            if bin > largest_bin
                largest_bin = bin
            end
            add(bins[bin], abs(pointdata[j, 3] - value1))
        end
    end


    bin_means::Array{Float64} = [mean(i) for i in bins]

    return [bin_distances[1:largest_bin] bin_means[1:largest_bin]]
end

"""
    Get the decorrelation length of a variogram.

    Returns -1 if no decorrelation length can be Calculated
"""
function getdecorrelationlength(variogram::Array{Float64, 2}, plot::Bool)

    local decorrelationlength::Int64 = -1
    fillgaps!(variogram)

    if size(variogram)[1] > 2
        local spline = SmoothingSplines.fit(SmoothingSplines.SmoothingSpline, variogram[:,1], variogram[:,2], 1e6)
        local smoothed = SmoothingSplines.predict(spline)
        
        if plot
            Plots.plot!(variogram[:,1], smoothed, linewidth=2)
        end

        limitindex::Int64 = getdecorrelationlimit(smoothed)
        if limitindex != -1
            decorrelationlength = variogram[limitindex, 1]
        end
    end

    return decorrelationlength
end

"""
    Fill gaps in a variogram using linear interpolation
"""
function fillgaps!(variogram::Array{Float64,2})

    local lastlag::Int64 = 0
    local currentlag::Int64 = 1

    while currentlag < size(variogram)[1]

        if !isnan(variogram[currentlag, 2])
            lastlag = currentlag
            currentlag +=  1
        else
            local nextgoodlag::Int64 = currentlag + 1
            while isnan(variogram[nextgoodlag, 2])
                nextgoodlag = nextgoodlag + 1
            end

            local gaplength::Int64 = nextgoodlag - lastlag
            local gaprange::Float64 = variogram[nextgoodlag, 2] - variogram[lastlag, 2]
            local stepsize::Float64 = gaprange / gaplength

            local fillstep::Int64 = 0
            for filllag in currentlag:nextgoodlag - 1
                fillstep += 1
                variogram[filllag, 2] = variogram[lastlag, 2] + (stepsize * fillstep)
            end

            currentlag = nextgoodlag + 1
            lastlag = currentlag - 1
        end
    end
end

"""
    Calculate the decorrelation limit for a variogram
    as the first step whose delta is less than 5%
    of the first positive delta of the varioagram.
"""
function getdecorrelationlimit(spline::Array{Float64, 1})

    local deltas::Array{Float64} = [(spline[i + 1] - spline[i]) for i in 1:length(spline) - 1]

    local position::Int64 = 1
    local firstpositivedelta::Float64 = 0

    # Find the first positive delta
    while firstpositivedelta == 0 && position <= length(deltas)
        if deltas[position] > 0
            firstpositivedelta = deltas[position]
        end
        position += 1
    end

    # Find the first delta that's smaller than 5% of the first positive delta
    local decorrelationposition::Int64 = -1

    while decorrelationposition == -1 && position < length(deltas)
        if deltas[position] <= 0 || deltas[position] / firstpositivedelta <= 0.05
            decorrelationposition = position
        else
            position += 1
        end
    end

    return decorrelationposition
end

end #Module
