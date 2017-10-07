library(ncdf4)

IN_DIR <- "cell_series_daily"
LAG_COUNT <- 365

coefficients <- vector(mode="numeric", length=144*72*(LAG_COUNT + 1))
dim(coefficients) <- c(144, 72, LAG_COUNT + 1)
coefficients[coefficients == 0] <- NA
significant <- coefficients


# Command line parameters
for (lon in 1:144) {
    cat("\rCalculating ACFs for", lon)

    for (lat in 1:72) {
        # Load the file
        in_file <- paste(IN_DIR, "/cell_series_", lon, "_", lat, ".csv", sep="")
        cell_series <- read.csv(in_file,header=F)[[2]]

        if (sum(!is.na(cell_series)) > 2) {

            sig_threshold <- qnorm((1 + 0.95) / 2) / sqrt(sum(!is.na(cell_series)))

            # Perform the autocorrelation calculation
            cor <- acf(cell_series, lag.max=LAG_COUNT, na.action=na.pass, plot=TRUE)

            for (i in 1:(LAG_COUNT + 1)) {
                if (!is.na(cor$acf[i])) {
                    coefficients[lon, lat, i] <- cor$acf[i]

                    if (abs(cor$acf[i]) > sig_threshold) {
                        significant[lon, lat, i] <- 1
                    } else {
                        significant[lon, lat, i] <- 0
                    }
                } 
            }

        }
    }
}

cat("\rWriting output       ")

lon_dim <- ncdim_def("lon", "degrees_east", seq(1.25, 358.75, 2.5))
lat_dim <- ncdim_def("lat", "degrees_north", seq(-88.75, 88.75, 2.5))
lag_dim <- ncdim_def("lag", "days", seq(0, 365), unlim=TRUE)

acf_var <- ncvar_def("acf", "r", list(lon_dim, lat_dim, lag_dim), -1e35, prec="double")
sig_var <- ncvar_def("significant", "boolean", list(lon_dim, lat_dim, lag_dim), -999, prec="short")

nc <- nc_create("pco2_temporal_acf.nc", list(acf_var, sig_var))
ncvar_put(nc, acf_var, coefficients)
ncvar_put(nc, sig_var, significant)
nc_close(nc)

cat("\n")

# TODO Decide what to do to make a sensible temporal correlation estimate for the interpolation
