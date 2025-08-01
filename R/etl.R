#' Initialize an `etl` object
#'
#' @description Initialize an `etl` object
#'
#' @param x the name of the `etl` package that you wish to populate with data.
#' This determines the class of the resulting `etl` object, which
#' determines method dispatch of `etl_*()` functions. There is no default,
#' but you can use [datasets::mtcars] as an test example.
#' @param db a database connection that inherits from [dplyr::src_dbi()].
#' It is NULL by default, which results in a [RSQLite::SQLite()] connection
#' being created in `dir`.
#' @param dir a directory to store the raw and processed data files
#' @param ... arguments passed to methods (currently ignored)
#' @details A constructor function that instantiates an `etl` object.
#' An `etl` object extends a [dplyr::src_dbi()] object.
#' It also has attributes for:
#' \describe{
#'  \item{pkg}{the name of the `etl` package corresponding to the data source}
#'  \item{dir}{the directory where the raw and processed data are stored}
#'  \item{raw_dir}{the directory where the raw data files are stored}
#'  \item{load_dir}{the directory where the processed data files are stored}
#'  }
#' Just like any [dplyr::src_dbi()] object, an `etl` object
#' is a data source backed by an SQL database. However, an `etl` object
#' has additional functionality based on the presumption that the SQL database
#' will be populated from data files stored on the local hard disk. The ETL functions
#' documented in [etl_create()] provide the necessary functionality
#' for **extract**ing data from the Internet to `raw_dir`,
#' **transform**ing those data
#' and placing the cleaned up data (usually in CSV format) into `load_dir`,
#' and finally **load**ing the clean data into the SQL database.
#' @return For `etl`, an object of class `etl_x` and
#' `etl` that inherits
#' from [dplyr::src_dbi()]
#' @export
#' @seealso etl_create()
#' @examples
#'
#' # Instantiate the etl object
#' cars <- etl("mtcars")
#' str(cars)
#' is.etl(cars)
#' summary(cars)
#'
#' \dontrun{
#' # connect to a PostgreSQL server
#' if (require(RPostgreSQL)) {
#'   db <- src_postgres("mtcars", user = "postgres", host = "localhost")
#'   cars <- etl("mtcars", db)
#' }
#' }
#'
#' # Do it step-by-step
#' cars |>
#'   etl_extract() |>
#'   etl_transform() |>
#'   etl_load()
#' src_tbls(cars)
#' cars |>
#'   tbl("mtcars") |>
#'   group_by(cyl) |>
#'   summarize(N = n(), mean_mpg = mean(mpg))
#'
#' # Do it all in one step
#' cars2 <- etl("mtcars")
#' cars2 |>
#'   etl_update()
#' src_tbls(cars2)
#'
etl <- function(x, db = NULL, dir = tempdir(), ...) UseMethod("etl")

#' @rdname etl
#' @export

etl.default <- function(x, db = NULL, dir = tempdir(), ...) {
  if (!x %in% c("mtcars", "cities")) {
    pkg <- x
    if (!requireNamespace(x, quietly = TRUE)) {
      stop(paste0("Please make sure that the '", x, "' package is installed"))
    }
  } else {
    pkg <- "etl"
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
  db <- verify_con(db, dir)
  obj <- structure(
    db,
    data = NULL,
    "pkg" = pkg,
    dir = normalizePath(dir),
    files = NULL, push = NULL,
    class = c(paste0("etl_", x), "etl", class(db))
  )

  # create subdirectories within dir
  raw_dir <- file.path(attr(obj, "dir"), "raw")
  if (!dir.exists(raw_dir)) {
    dir.create(raw_dir)
  }
  load_dir <- file.path(attr(obj, "dir"), "load")
  if (!dir.exists(load_dir)) {
    dir.create(load_dir)
  }
  attr(obj, "raw_dir") <- raw_dir
  attr(obj, "load_dir") <- load_dir
  return(obj)
}

#' @rdname etl
#' @inheritParams base::summary
#' @export
#' @examples
#'
#' # generic summary function provides information about the object
#' cars <- etl("mtcars")
#' summary(cars)
summary.etl <- function(object, ...) {
  cat("files:\n")
  dplyr::bind_rows(
    summary_dir(attr(object, "raw_dir")),
    summary_dir(attr(object, "load_dir"))
  ) |>
    print()
  NextMethod()
}

summary_dir <- function(dir) {
  files <- file.info(list.files(dir, full.names = TRUE))
  # filesize in GB
  data.frame(
    n = nrow(files),
    size = paste(round(sum(files$size) / 10^9, digits = 3), "GB"),
    path = dir, stringsAsFactors = FALSE
  )
}

#' @rdname etl
#' @export
#' @inheritParams summary.etl
#' @return For [is.etl()], `TRUE` or `FALSE`,
#' depending on whether `x` has class `etl`
#' @examples
#' cars <- etl("mtcars")
#' # returns TRUE
#' is.etl(cars)
#'
#' # returns FALSE
#' is.etl("hello world")
is.etl <- function(object) inherits(object, "etl")

#' @rdname etl
#' @export
#' @inheritParams base::print
#' @examples
#' cars <- etl("mtcars") |>
#'   etl_create()
#' cars
print.etl <- function(x, ...) {
  file_info <- dplyr::bind_rows(
    summary_dir(attr(x, "raw_dir")),
    summary_dir(attr(x, "load_dir"))
  ) |>
    summarize(N = sum(n), size = sum(readr::parse_number(size)))
  cat("dir:  ", file_info$N, " files occupying ",
    file_info$size, " GB\n",
    sep = ""
  )
  NextMethod()
}
