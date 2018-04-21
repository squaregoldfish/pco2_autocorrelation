const INFILE = "SOCATv5_all.tsv"
const OUTDIR = "cell_series_daily"
const CELLSIZE = 2.5
const STARTYEAR = 1985
const ENDYEAR = 2016

# Zero-based day of year of each month
const MONTHSTARTS = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
const LEAPMONTHSTARTS = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

# Days of the year
DAYSTARTS = linspace(1, 365, 365)

# Calculate the conversion of leap year days to 365 'normal' year days
# Each leap year day lasts 1 1/365 normal days 
LEAPDAYSTARTS = Array{Float64}(365)

for i in 1:365
    LEAPDAYSTARTS[i] = i + (((366 / 365) / 365) * (i - 1))
end

# Determine whether or not a given year is a leap year
function isleapyear(year::Int64)::Bool
    local leapyear::Bool = false
    if rem(year, 4) == 0
        leapyear = true
        if rem(year, 100) == 0
            if rem(year, 400) != 0
                leapyear = false
            end
        end
    end

    leapyear
end

# Calculate the Julian day from a year/month/day set
function calcjdate(year::Int64, month::Int64, day::Int64)::Int64
    local result::Int64 = 0

    if isleapyear(year)
        result = LEAPMONTHSTARTS[month]
    else
        result = MONTHSTARTS[month]
    end

    result = result + day
end

# Calculate the day of the year for a given date
function getdayindex(date, days)::Float64
    return days[findlast(find(days .<= date))]
end

# Calcaulte the nth day of the complete data set
# Days are only calculated between the start and end years
function getdateindex(year::Int64, month::Int64, day::Int64)::Int64
    
    local jdate::Float64 = calcjdate(year, month, day)    
    local index::Float64 = -1
    local dayindex::Float64 = 0

    if year >= STARTYEAR && year <= ENDYEAR
        if isleapyear(year)
            dayindex = getdayindex(jdate, DAYSTARTS)
        else
            dayindex = getdayindex(jdate, LEAPDAYSTARTS)
        end
    
        index = ((year - STARTYEAR) * 365) + dayindex
    end

    return convert(Int64, floor(index))
end

# Calculate the cell indices from a longitude and latitude
function getcellindex(longitude::Float64, latitude::Float64)::Tuple{Int64, Int64}
    local loncell::Int64 = floor(longitude / CELLSIZE) + 1
    local latcell::Int64 = floor((latitude + 90) / CELLSIZE) + 1

    if loncell == 145
        loncell = 1
    end

    return loncell, latcell
end

function run()

    totaldays::Int64 = (ENDYEAR - STARTYEAR + 1) * 365

    # Output data set
    celltotals::Array{Float64, 3} = zeros(convert(Int64, 360 / CELLSIZE), convert(Int64, 180 / CELLSIZE), totaldays)
    cellcounts::Array{Int64, 3} = zeros(convert(Int64, 360 / CELLSIZE), convert(Int64, 180 / CELLSIZE), totaldays)

    # Open input file
    inchan::IOStream = open(INFILE)

    currentline::String = readline(inchan)
    linecount::Int64 = 1

    while length(currentline) > 0

        fields::Array{String, 1} = split(currentline, "\t")

        year::Int64 = parse(Int64, fields[5])
        month::Int64 = parse(Int64, fields[6])
        day::Int64 = parse(Int64, fields[7])
        longitude::Float64 = parse(Float64, fields[11])
        latitude::Float64 = parse(Float64, fields[12])
        fco2::Float64 = parse(Float64, fields[24])

        cellindex::Tuple{Int64, Int64} = getcellindex(longitude, latitude)

        dateindex::Int64 = getdateindex(year, month, day)

        if dateindex != -1
            celltotals[cellindex[1], cellindex[2], dateindex] = celltotals[cellindex[1], cellindex[2], dateindex] + fco2
            cellcounts[cellindex[1], cellindex[2], dateindex] = cellcounts[cellindex[1], cellindex[2], dateindex] + 1
        end

        currentline = readline(inchan)
        linecount += 1
        if rem(linecount, 10000) == 0
            print("\033[1K\r$linecount")
        end
    end

    close(inchan)

    for lon in 1:convert(Int64, 360 / CELLSIZE)
        for lat in 1:convert(Int64, 180 / CELLSIZE)
            print("\033[1K\rWriting $lon $lat")
            outchan::IOStream = open("$(OUTDIR)/cell_series_daily_$(lon)_$(lat).csv", "w")
            for day in 1:totaldays
                if cellcounts[lon, lat, day] == 0
                    write(outchan, "$day,NaN\n")
                else
                    local meanfco2::Float64 = celltotals[lon, lat, day] / cellcounts[lon, lat, day]
                    write(outchan, "$day,$(meanfco2)\n")                    
                end
            end
            close(outchan)
        end
    end

    println()
end

run()