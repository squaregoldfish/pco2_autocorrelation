# Command line parameters
for (arg in commandArgs()) {
    argset <- strsplit(arg, "=", fixed=TRUE)
    if (!is.na(argset[[1]][2])) {
        if (argset[[1]][1] == "lon") {
            assign("lon",argset[[1]][2])
        } else if (argset[[1]][1] == "lat") {
            assign("lat",argset[[1]][2])
        } else if (argset[[1]][1] == "indir") {
            assign("indir",argset[[1]][2])
        } else if (argset[[1]][1] == "outdir") {
            assign("outdir",argset[[1]][2])
        }
    }
}

lon <- as.integer(lon)
lat <- as.integer(lat)

in_file <- paste(indir, "/cell_series_", lon, "_", lat, ".csv", sep="")

cell_series <- read.csv(in_file,header=F)[[2]]

cor <- acf(cell_series, lag.max=365, na.action=na.pass, plot=TRUE)

print(cor)