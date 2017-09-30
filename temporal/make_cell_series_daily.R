# Project all SOCAT measurements into daily mean files on a 2.5°x2.5° grid

# NB REQUIRES THAT ALL HEADER LINES ARE REMOVED.

SOCAT_FILE <- "SOCATv5.tsv" # The SOCAT measurements file
SOCAT_LINES <- 21484305 # The number of lines in the SOCAT file (for progress updates)

START_YEAR <- 1985 # The first year being processed
END_YEAR <- 2016 # The last year being processed
TOTAL_DAYS <- 11681 # The number of days being processed

# Zero-based day of year of each month
MONTH_STARTS <- c(0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)
LEAP_MONTH_STARTS <- c(0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335)

# Days of the year
DAY_STARTS <- seq(1, 365)

# Calculate the conversion of leap year days to 365 'normal' year days
# Each leap year day lasts 1 1/365 normal days 
LEAP_DAY_STARTS <- vector(mode="numeric", length=365)

for (i in 1:365) {
    LEAP_DAY_STARTS[i] <- i + (((366 / 365) / 365) * (i - 1))
}

# Calculate the Julian day from a year/month/day set
calcJDate <- function(year, month, day) {
    result <- 0

    if (isLeapYear(year)) {
        result <- LEAP_MONTH_STARTS[month]
    } else {
        result <- MONTH_STARTS[month]
    }

    result <- result + day

    return (result)
}

# Calcaulte the nth day of the complete data set
# Days are only calculated between the start and end years
getDateIndex <- function(year, month, day) {

    jdate <- calcJDate(year, month, day)

    index <- NULL
    day_index = 0

    if (year >= START_YEAR && year <= END_YEAR) {
        if (isLeapYear(year)) {
            day_index <- getDayIndex(jdate, DAY_STARTS)
        } else {
            day_index <- getDayIndex(jdate, LEAP_DAY_STARTS)
        }
    
        index <- ((year - START_YEAR) * 365) + day_index
    }

    return (index)
}

# Calcualte the day of the year for a given date
getDayIndex <- function(date, days) {
    return  (tail(which(days < date), 1))
}

# Determine whether or not a given year is a leap year
isLeapYear <- function(year) {
    leap_year <- FALSE
    if (year %% 4 == 0) {
        leap_year <- TRUE
        if (year %% 100 == 0) {
            if (year %% 400 != 0) {
                leap_year <- FALSE
            }
        }
    }

    return (leap_year)
}

# Get the cell index that a given latitude falls into
getLatCell <- function(lat) {
    boundary <- trunc(lat / 2.5)
    cell <- boundary + 36
    if (lat > 0) {
        cell <- cell + 1
    }
    return (cell)
}

# Get the cell index that a given longitude falls into
getLonCell <- function(lon) {
    result <- (trunc(lon / 2.5) + 1)
    if (result == 145) {
        result <- 144
    }
    return (result)
}

###############################################

# The array of measurment totals and counts for each cell and day
totals <- array(0, c(144,72,TOTAL_DAYS))
counts <- array(0, c(144,72,TOTAL_DAYS))

# Open the input file
conn <- file(SOCAT_FILE,open="r")

# Loop through all the lines
line <- readLines(conn,n=1)
line_count <- 1

while (length(line) > 0) {

    # Progress update
    if (line_count %% 1000 == 0) {
        cat("\r", line_count, " of ", SOCAT_LINES, " (", sprintf("%.2f", (line_count / SOCAT_LINES) * 100), "%)", sep="")
    }

    # Extract the required fields from the line
    fields <- unlist(strsplit(line, "\t"))
    
    year <- as.numeric(fields[5])
    month <- as.numeric(fields[6])
    day <- as.numeric(fields[7])

    lat <- as.numeric(fields[12])
    lon <- as.numeric(fields[11])
    fco2 <- as.numeric(fields[24])

    # If there's a recorded fCO2 measurement with complete date info...
    if (!is.null(fco2) && !is.na(fco2)) {

        if (!is.null(year) && !is.null(month) && !is.null(day) && !is.null(lat) && !is.null(lon) && !is.null(fco2)) {
            if (!is.na(year) && !is.null(month) && !is.na(day) && !is.na(lat) && !is.na(lon) && !is.na(fco2)) {

                # Convert longitudes to 0:360 range
                if (lon < 0) {
                    lon <- 360 - abs(lon)
                }

                # Calculate the date index
                date_index <- getDateIndex(year, month, day)

                # Add the value to the data set
                if (!is.null(date_index)) {
                    lat_cell <- getLatCell(lat)
                    lon_cell <- getLonCell(lon)

                    totals[lon_cell, lat_cell, date_index] <- totals[lon_cell, lat_cell, date_index] + fco2
                    counts[lon_cell, lat_cell, date_index] <- counts[lon_cell, lat_cell, date_index] + 1
                }
            }
        }
    }

    line <- readLines(conn,n=1)
    line_count <- line_count + 1
}

cat("\n")


# Loop through each grid cell
for (lon in 1:144) {
    for (lat in 1:72) {
        cat("\r","Output file",lon,lat)

        output <- vector(mode="numeric", length=TOTAL_DAYS)
        output[output == 0] <- NA

        # Calculate mean daily value
        for (i in 1:TOTAL_DAYS) {
            if (counts[lon, lat, i] > 0) {
                output[i] <- totals[lon, lat, i] / counts[lon, lat, i]
            }
        }

        if (sum(!is.na(output)) > 2) {
            # Remove outliers (3 standard deviations from mean)
            outliers_removed <- TRUE
            while (outliers_removed == TRUE) {
                outliers_removed <- FALSE
                old_count <- sum(!is.na(output))

                series_mean <- mean(output, na.rm=T)
                stdev <- sd(output, na.rm=T)

                output[output > (series_mean + (stdev * 3))] <- NA
                output[output < (series_mean - (stdev * 3))] <- NA

                new_count <- sum(!is.na(output))

                if (new_count != old_count) {
                    cat("  Outliers removed: ",lon,lat,old_count - new_count,"\n")
                    outliers_removed <- TRUE
                }
            }
        }

        # Write the cell series file
        out_file <- paste("cell_series_daily/cell_series_",lon,"_",lat,".csv",sep="")
        sink(out_file)
        for (i in 1:TOTAL_DAYS) {
            cat(i,",",output[i],"\n",sep="")
        }

        sink()
    }
}
cat("\n")
