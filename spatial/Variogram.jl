module Variogram
using Distances
using LsqFit

export variogram
export fit
export polyfit

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
    Fit an exponential curve to a variogram
"""
function fit(variogram::Array{Float64, 2})
    model(x, p) = p[1]*(1 - exp.(-x./p[2]))
    local p0::Array{Float64, 1} = [250.0, 50.0]
    local fit = curve_fit(model, variogram[:,1], variogram[:,2], p0)
    return fit.param
end

function polyfit(variogram::Array{Float64, 2})
    model(x, p) = p[1] + p[2]x + p[3]x.^2 + p[4]x.^3 + p[5]x.^4 + p[6]x.^5 + p[7]x.^6 + p[8]x.^7 + p[9]x.^8 + p[10]x.^9 + p[11]x.^10
    local p0::Array{Float64, 1} = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    local fit = curve_fit(model, variogram[:,1], variogram[:,2], p0)
    return fit.param
end


end #Module
