const INFILE = "SOCATv5_all.tsv"::String
const OUTDIR = "datasets"::String

function run()

    # Open input file
    inchan = open(INFILE)

    # Tracking variables
    currentdataset = Nullable{String}()
    outchan = Nullable{Any}()

    currentline = readline(inchan)
    linecount = 1

    # Loop until the end of the file
    while length(currentline) > 0
        
        fields = split(currentline, "\t")
        dataset = fields[1]

        # See if the dataset has changed
        if dataset != currentdataset

            # Close the existing output file
            if !isnull(outchan)
                close(outchan)
            end

            currentdataset = dataset

            # Open a new output file
            outchan = open(OUTDIR * "/" * currentdataset * ".tsv", "w")
            #write(outchan, "date\tlon\tlat\tfco2\n")
            write(outchan, "lon\tlat\tfco2\n")
            print("\033[2K\r $linecount $currentdataset")
        end

        # Write the line to the output file, only using the bits we need
        #year = fields[5]
        #month = fields[6]
        #day = fields[7]
        #hour = fields[8]
        #minute = fields[9]
        #second = fields[10][1:2]
        lon = fields[11]
        lat = fields[12]
        fco2 = fields[24]

#       write(outchan, "$year/$month/$day $hour:$minute:$second\t$lon\t$lat\t$fco2\n")
        write(outchan, "$lon\t$lat\t$fco2\n")

        currentline = readline(inchan)
        linecount += 1
    end

    if !isnull(outchan)
        close(outchan)
    end

    # Close input file
    close(inchan)

    print("\n")
end

@time run()
