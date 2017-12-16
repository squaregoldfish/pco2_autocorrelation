module Variogram
using Distances

export variogram

"""
    Utility type to collect values and eventually calculate a mean
"""
type BuildMean
    total::Float64
    entries::Int

    BuildMean() = new(0.0, 0)
end

"""
   Add a value to a mean
"""
function add(x::BuildMean, value::Float64)
    x.total += value
    x.entries += 1
end

"""
   Calculate the final value of a mean
"""
function mean(x::BuildMean)
    result::Float64 = NaN

    if x.entries > 0
        result = x.total / x.entries

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
    bins::Array{BuildMean} = [BuildMean() for i = 1:ceil(20037.5 / binsize)]
    bin_distances::Array{Int64} = collect(25:binsize:20037.5)

    # Go through every pair of points, and
    # add the difference in value between each pair
    # to the appropriate bin
    npoints::Int64 = size(pointdata)[1]

    for i in 1:npoints - 1

        point1::Array{Float64} = pointdata[i, 1:2]
        value1::Float64 = pointdata[i, 3]

        for j in i + 1:npoints
            
            point2::Array{Float64} = pointdata[j, 1:2]

            distance::Float64 = evaluate(Distances.Haversine(6371), point1, point2)
            bin::Int64 = Int64(floor(distance / 50)) + 1
            add(bins[bin], abs(pointdata[j, 3] - value1))
        end
    end

    bin_means::Array{Float64} = [mean(i) for i in bins]

    return [bin_distances bin_means]
end


end #Module
