#! /usr/bin/env Rscript

# Exit codes.
error <- data.frame(
    io = 10,
    argparse = 11,
    filetype = 12
)

# Install required packages.
is.installed <- function(pkg) {
    return(pkg %in% rownames(installed.packages()))
}
is.attached <- function(pkg) {
    return(pkg %in% .packages())
}
install.and.attach <- function(pkg) {
    if(!(is.installed(pkg))) {
        install.packages(pkg)
    }
    if(!(is.attached(pkg))) {
        library(pkg, character.only = TRUE)
    }
}
required.packages <- c("getopt", "tools")
loading.output <- sapply(required.packages, invisible(install.and.attach))

# Process options.
no.args <- 0
required <- 1
optional <- 2
input.args <- matrix(c(
    "candidates", "c", optional, "character",
    "assessors",  "a", optional, "character",
    "exams",      "e", optional, "character",
    "locations",  "l", optional, "character"
), byrow = TRUE, ncol = 4)
other.args <- matrix(c(
    "session",    "s", optional, "character",
    "rests",      "r", optional, "character",
    "outfile",    "o", optional, "character",
    "verbose",    "v", optional, "character",
    "help",       "h", optional, "character"
), byrow = TRUE, ncol = 4)
spec <- rbind(input.args, other.args)
opt <- getopt(spec)
usage <- function() {
    cat("lachesis.r -c FILENAME -a FILENAME -e FILENAME -l FILENAME [-o FILENAME]\n")
    cat("\n")
    cat("Generates a roster that assigns assessors to cases in an exam matrix\n")
    cat("and timetables candidates to cycle between assessors at a venue.\n")
    cat("\n")
    cat("Valid filetypes are csv, xls and xlsx.")
    cat("\n")
    cat("    --candidates -c    Spreadsheet with candidate info.\n")
    cat("    --assessors  -a    Spreadsheet with assessor info.\n")
    cat("    --exams      -e    Spreadsheet with exam matrix info.\n")
    cat("    --locations  -l    Spreadsheet with venue info.\n")
    cat("    --session    -s    Specify AM or PM.\n")
    cat("    --outfile    -o    Spreadsheet for storing final master roster.\n")
    cat("    --verbose    -v    Print debugging information to stderr.\n")
    cat("    --help       -h    Print this usage information.\n")
    cat("\n")
    cat("If --outfile is not given, will output to stdout.\n")
}
if(!is.null(opt$help)) {
    usage()
    quit(status = 0)
}
verbose <- FALSE
if(!is.null(opt$verbose)) {
    verbose <- TRUE
}
session <- NA
if(!is.null(opt$session)) {
    session <- toupper(opt$session)
}
n.rests <- 4
if(!is.null(opt$rests)) {
    n.rests <- as.numeric(opt$rests)
}

# Validate options.
validate.option <- function(option.name) {
    option <- opt[[option.name]]
    if(is.null(option)) {
        cat("Required option not given:", option.name, "\n")
        return(FALSE)
    }
    if(option.name != "outfile" && !file.exists(option)) {
        cat("File does not exist:", option, "\n")
        return(FALSE)
    }
    return(TRUE)
}
required.args <- which(spec[,3] == required)
opt.output <- sapply(spec[required.args, 1], validate.option)
if(!all(opt.output)) {
    quit(status = error$argparse)
}
output <- "stdout"
if(!is.null(opt$outfile)) {
    output <- opt$outfile
}

# Provide some default filenames in case we're not calling this script from a shell.
if(is.null(opt$candidates)) {
    opt$candidates <- "candidates.csv"
}
if(is.null(opt$assessors)) {
    opt$assessors <- "assessors.csv"
}
if(is.null(opt$exams)) {
    opt$exams <- "exams.csv"
}
if(is.null(opt$locations)) {
    opt$locations <- "locations.csv"
}

# Extract data from input files.
if(verbose) {
    sink("/dev/stderr")
    cat("Reading data files ... ")
    sink()
}
load.data <- function(option.name) {
    filename <- opt[[option.name]]
    if(!file.exists(filename)) {
        cat("File does not exist:", filename, "\n")
        quit(status = error$io)
    }
    x <- file_ext(filename)
    input <- NULL
    if(x == "csv") {
        input <- read.csv(filename, stringsAsFactors = FALSE)
    } else if (x %in% c("xls", "xlsx")) {
        suppressMessages(install.and.attach("xlsx"))
        input <- read.xlsx2(filename, 1, stringsAsFactors = FALSE)
    } else {
        cat("Unknown file extension", x, "for file name", filename, "\n")
        quit(status = error$filetype)
    }
    if(verbose) {
        sink("/dev/stderr")
        cat(filename, "... ")
        sink()
    }
    return(input)
}
data <- lapply(input.args[,1], load.data)
if(verbose) {
    cat("done.\n")
}
names(data) <- input.args[,1]

# Tidy up data a bit:
# - Remove irrelevant columns.
# - Convert "yes/no/blank" to logicals.
# - Convert examiner birth dates to current age.
# - Convert availability of "AM PM" to "BOTH".
# - Standardise column names.
exam.matrix.keep <- c(1, 5:7, 21)
data$exams <- data$exams[exam.matrix.keep] # Only keep relevant data.
data$exams$Case.Gender[data$exams$Case.Gender == "Either"] <- NA
data$exams$Case.Age <- as.numeric(data$exams$Case.Age)
data$assessors$Assigned <- rep(FALSE, dim(data$assessors)[1])
data$exams$Assessor1 <- rep(0, dim(data$exams)[1])
data$exams$Assessor2 <- rep(0, dim(data$exams)[1])

yesno2logical <- function(input) {
    return(input == "Yes" | input == "Y")
}
data$exams$ATSIH <- yesno2logical(data$exams$ATSIH)
data$assessors$ATSIH <- yesno2logical(data$assessors$ATSIH)

install.and.attach("lubridate")
age <- function(dob, age.day = today(), units = "years", floor = TRUE) {
    # Converts dates of birth to age.
    # (Via http://stackoverflow.com/a/27364453)
    calc.age = new_interval(dob, age.day) / duration(num = 1, units = units)
    if (floor) {
        return(as.integer(floor(calc.age)))
    }
    return(calc.age)
}
data$assessors$Age <- age(data$assessors$BIRTH_DATE)

data$assessors$Avail[data$assessors$Avail == "AM PM"] <- "BOTH"
names(data$assessors)[names(data$assessors) == "GENDER"] <- "Gender"
names(data$exams)[names(data$exams) == "Case.Gender"] <- "Gender"
names(data$exams)[names(data$exams) == "Case.Age"] <- "Age"

numeric2date <- function(excel.date) {
    # When required, use this to convert Excel's numerical "date" format to actual dates.
    return(as.Date(as.numeric(data$assessors$BIRTH_DATE) - 25569, origin = "1970-01-01"))
}
filter <- function(search.terms) {
    # Use something like this to generate pruned data for testing.
    data$candidates <- data$candidates[data$candidates["Venue"] %in% search.terms,]
    data$assessors <- data$assessors[data$assessors["STATE_PROVINCE"] %in% search.terms,]
    data$locations <- data$locations[data$locations["City"] %in% search.terms,]
    write.csv(data$candidates, "./vic-candidates.csv")
    write.csv(data$assessors, "./vic-assessors.csv")
    write.csv(data$locations, "./vic-locations.csv")
}

#assessors.sorted <- data$assessors[with(data$assessors, order(Avail, -ATSIH, Gender, Age)),]
exams.sorted <- data$exams[with(data$exams, order(-ATSIH, Gender, Age)),]

age.match <- function(assessor.age, case.age) {
    if(case.age >= 18) {
        return(assessor.age %in% (case.age - 10):(case.age + 10))
    } else { # Assessor to simulate older relative.
        return(TRUE)
    }
}

# Just deal with first case for the moment;
# can generalise to matching all cases once we know we
# can find a match to at least one case.
session.match <- c(session, "BOTH")
find.assessor1 <- function(case) {
    session.match <- c(session, "BOTH")
    matches <- list(
        ATSIH = which(data$assessors$ATSIH == case$ATSIH
            & data$assessors$Assigned == FALSE
            & data$assessors$Avail %in% session.match),
        Gender = which(data$assessors$Gender == case$Gender
            & data$assessors$Assigned == FALSE
            & data$assessors$Avail %in% session.match),
        Age = which(age.match(data$assessors$Age, case$Age
            & data$assessors$Assigned == FALSE
            & data$assessors$Avail %in% session.match))
    )

    # Build possible matches between cases and examiners.
    # Include imperfect matches to pre-empt the event that no perfect match is available.
    match.combns <- lapply(0:length(matches),
        # First construct all the combinations of match comparisons.
        function(x) {
            return(combn(length(matches), x))
        }
    )
    intersections <- lapply(1:length(match.combns),
        function(x) {
            return(lapply(1:dim(match.combns[[x]])[2],
                function(cmb) {
                    return(Reduce(intersect, matches[match.combns[[x]][,cmb]]))
                }
            ))
        }
    )
    intersections[[1]][[1]] <- 1:dim(data$assessors)[1]
    for(n in 1:length(match.combns)) {
        names(intersections[[n]]) <- sapply(1:dim(match.combns[[n]])[2],
            function(cmb) {
                return(paste(names(matches)[as.vector(match.combns[[n]][,cmb])], collapse = "."))
            }
        )
    }
    names(intersections[[1]]) <- "Unconstrained"

    idx <- 0
    found <- FALSE
    imperfect.match <- FALSE
    none.match <- FALSE
    for(x in length(intersections):1) {
        if(x == 1) { # We've exhausted all perfect and imperfect matches, which is a problem.
            none.match <- TRUE
        }
        for(cmb in names(intersections[[x]])) {
            if(length(intersections[[x]][[cmb]]) > 0) {
                idx <- intersections[[x]][[cmb]][1]
                found <- TRUE
                break
            }
        }
        if(found) {
            break
        }
        warning <- TRUE # If we get to here we didn't find a perfect match.
    }
    if(imperfect.match | none.match) {
        sink("/dev/stderr")
        cat("Warning: ")
        if(none.match) {
            cat("no matches found. Assigned non-matching person.")
        } else if (imperfect.match) {
            cat("no perfect matches found. Assigned imperfect match.")
        }
        cat("\n")
        sink()
    }
    return(idx)
}
find.assessor2 <- function() {
    available <- which(data$assessors$Avail %in% session.match)
    return(data$assessors[available[1], "ID"])
}
for(case in 1:dim(exams.sorted)[1]) {
    case.number <- exams.sorted[case, "Case.No"]
    assessor1 <- find.assessor1(data$exams[case.number,])
    data$assessors[assessor1, "Assigned"] <- TRUE
    data$exams[case.number, "Assessor1"] <- data$assessors[assessor1, "ID"]
}
for(case in 1:dim(exams.sorted)[1]) {
    assessor2 <- find.assessor2()
    data$assessors[assessor2, "Assigned"] <- TRUE
    data$exams[case.number, "Assessor2"] <- data$assessors[assessor2, "ID"]
}
#data$assessors[data$assessors[,"Assigned"] == TRUE,]
#data$exams

n.sessions <- dim(data$exams)[1] + n.rests
candidates1 <- data$candidates[1:n.sessions,]
timetable <- matrix(sapply(1:n.sessions,
    function(offset) {
        return(candidates1[(1:n.sessions - offset) %% n.sessions + 1, "ID"])
    }
), nrow = n.sessions)

if(verbose) {
    warnings()
}
