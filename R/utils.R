if(getRversion() >= "2.15.1") {
  utils::globalVariables(c(".", "year", "month"))
}

#' @import dplyr

# ensure we have a valid database connection
verify_con <- function(x, dir = tempdir()) {
  if (!inherits(x, "src")) {
    sqlite_file <- tempfile(fileext = ".sqlite3", tmpdir = dir)
    message("No database was specified so I created one for you at:")
    message(sqlite_file)
    con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_file)
    x <- dbplyr::src_dbi(con)
  }
  x
}

# make sure we're dealing with a _list of_ data frames
# verify_dat <- function(dat) {
#   if (is.data.frame(dat)) dat <- list(dat)
#   is_df <- vapply(dat, is.data.frame, logical(1))
#   if (!all(is_df))
#     warning("Detected data objects that aren't data frames.\n",
#             "These will not be exported to the database.")
#   dat[is_df]
# }


#' Ensure that years and months are within a certain time span
#' @param years a numeric vector of years
#' @param months a numeric vector of months
#' @param begin the earliest valid date, defaults to the UNIX epoch
#' @param end the most recent valid date, defaults to today
#' @details Often, a data source will `begin` and `end` at
#' known points in time. At the same time, many data sources are divided
#' into monthly archives. Given a set of `years` and `months`,
#' any combination of which should be considered valid, this function will
#' return a [data.frame] in which each row is one of those
#' valid year-month pairs. Further, if the optional `begin` and
#' `end` arguments are specified, the rows will be filter to lie
#' within that time interval. Furthermore, the first and last day of
#' each month are computed.
#' @return a [data.frame] with four variables: `year`,
#' `month`, `month_begin` (the first day of the month), and
#' `month_end` (the last day of the month).
#' @export
#' @examples
#'
#' valid_year_month(years = 1999:2001, months = c(1:3, 7))
#'
#' # Mets in the World Series since the UNIX epoch
#' mets_ws <- c(1969, 1973, 1986, 2000, 2015)
#' valid_year_month(years = mets_ws, months = 10)
#'
#' # Mets in the World Series during the Clinton administration
#' if (require(ggplot2)) {
#'   clinton <- filter(presidential, name == "Clinton")
#'   valid_year_month(years = mets_ws, months = 10,
#'     begin = clinton$start, end = clinton$end)
#' }
#'
valid_year_month <- function(years, months,
                             begin = "1870-01-01", end = Sys.Date()) {
  years <- as.numeric(years)
  months <- as.numeric(months)
  begin <- as.Date(begin)
  end <- as.Date(end)

  valid_months <- tibble::tibble(expand.grid(years, months)) |>
    rename(year = Var1, month = Var2) |>
    mutate(
      month_begin = lubridate::ymd(paste(year, month, "01", sep = "/")),
      month_end = lubridate::ymd(
        ifelse(month == 12, paste(year + 1, "01/01", sep = "/"),
               paste(year, month + 1, "01", sep = "/"))) - 1) |>
    filter(
      year > 0 & month >= 1 & month <= 12,
      month_begin >= begin & month_begin <= end
    ) |>
    arrange(month_begin)
  return(valid_months)
}



#' Match year and month vectors to filenames
#' @description Match year and month vectors to filenames
#' @param years a numeric vector of years
#' @param months a numeric vector of months
#' @return a character vector of `files` that match the `pattern`, `year`, and `month` arguments
#' @export
#' @examples
#' \dontrun{
#' if (require(airlines)) {
#'   airlines <- etl("airlines", dir = "~/Data/airlines") |>
#'     etl_extract(year = 1987)
#'   summary(airlines)
#'   match_files_by_year_months(list.files(attr(airlines, "raw_dir")),
#'     pattern = "On_Time_On_Time_Performance_%Y_%m.zip", year = 1987)
#' }
#' }

match_files_by_year_months <- function(files, pattern,
                                       years = as.numeric(
                                         format(Sys.Date(), '%Y')),
                                       months = 1:12, ...) {
  if (length(files) < 1) {
    return(NULL)
  }
  file_df <- tibble::tibble(
    filename = files,
    file_date = extract_date_from_filename(files, pattern)) |>
    mutate(
      file_year = lubridate::year(file_date),
      file_month = lubridate::month(file_date)
    )
  valid <- valid_year_month(years, months)
  good <- file_df |>
    left_join(valid, by = c("file_year" = "year", "file_month" = "month")) |>
    filter(!is.na(month_begin))
  return(fs::as_fs_path(good$filename))
}

#' @description Extracts a date from filenames
#' @param files a character vector of filenames
#' @param pattern a regular expression to be passed to [lubridate::fast_strptime()]
#' @param ... arguments passed to [lubridate::fast_strptime()]
#' @return a vector of [base::POSIXct] dates matching the pattern
#' @export
#' @rdname match_files_by_year_months

extract_date_from_filename <- function(files, pattern, ...) {
  if (length(files) < 1) {
    return(NULL)
  }
  files |>
    basename() |>
    lubridate::fast_strptime(format = pattern, ...) |>
    # why does it always return the previous day?
    as.Date() + lubridate::days(1)
}

#' Wipe out all tables in a database
#' @details Finds all tables within a database and removes them
#' @param conn a [DBI::DBIConnection-class] object
#' @param ... arguments passed to [DBI::dbRemoveTable()]
#' @export

dbWipe <- function(conn, ...) {
  x <- DBI::dbListTables(conn)
  if (length(x) > 0) {
    lapply(x, DBI::dbRemoveTable, conn = conn, ... = ...)
  }
}

#' Connect to local MySQL Server using ~/.my.cnf
#' @param dbname name of the local database you wish to connect to. Default is
#' `test`, as in [RMariaDB::mariadbHasDefault()].
#' @param groups section of `~/.my.cnf` file. Default is `rs-dbi` as in
#' [RMariaDB::mariadbHasDefault()]
#' @param ... arguments passed to [dplyr::src_mysql()]
#' @export
#' @seealso [dplyr::src_mysql()], [RMariaDB::mariadbHasDefault()]
#' @examples
#' if (require(RMariaDB) && mariadbHasDefault()) {
#'   # connect to test database using rs-dbi
#'   db <- src_mysql_cnf()
#'   class(db)
#'   db
#'   # connect to another server using the 'client' group
#'   src_mysql_cnf(groups = "client")
#' }
src_mysql_cnf <- function(dbname = "test", groups = "rs-dbi", ...) {
  config_file_path <- file.path("~", ".my.cnf")
  if (!file.exists(config_file_path)) {
    warning("No MySQL config file found...trying anyway...")
    tryCatch({
      dplyr::src_mysql(groups = groups, dbname = dbname,
                       user = NULL, password = NULL, ...)
    }, error = function(...) {
        message("Could not connect to mysql source.")
        return(FALSE)
    })
  } else {
    dplyr::src_mysql(default.file = config_file_path,
              groups = groups, dbname = dbname,
              user = NULL, password = NULL, ...)
  }
}

#' Return the database type for an ETL or DBI connection
#' @param obj and [etl] or [DBI::DBIConnection-class] object
#' @param ... currently ignored
#' @export
#' @examples
#' if (require(RMariaDB) && mariadbHasDefault()) {
#'   # connect to test database using rs-dbi
#'   db <- src_mysql_cnf()
#'   class(db)
#'   db
#'   # connect to another server using the 'client' group
#'   db_type(db)
#'   db_type(db$con)
#' }

db_type <- function(obj, ...) UseMethod("db_type")

#' @rdname db_type
#' @export

db_type.src_dbi <- function(obj, ...) {
  db_type(obj$con)
}

#' @rdname db_type
#' @export

db_type.DBIConnection <- function(obj, ...) {
  class(obj) |>
    gsub(pattern = "Connection", replacement = "", x = _) |>
    tolower() |>
    utils::head(1)
}

#' Create an ETL package skeleton
#' @param ... arguments passed to [usethis::create_package()]
#' @export
#' @details Extends [usethis::create_package()] and places a template source file in
#' the R subdirectory of the new package. The file has a working stub of [etl_extract()].
#' The new package can be built immediately and run.
#'
#' New S3 methods for [etl_transform()] and [etl_load()] can be added if
#' necessary, but the default methods may suffice.
#' @seealso [etl_extract()], [etl_transform()], [etl_load()]
#' @examples
#' \dontrun{
#' path <- file.path(tempdir(), "scorecard")
#' create_etl_package(path)
#' }
#' # Now switch projects, and "Install and Restart"

create_etl_package <- function(...) {
  usethis::create_package(...)
  path <- list(...)[[1]]
  # pkg <- devtools:::extract_package_name(path)
  pkg <- basename(normalizePath(path, mustWork = FALSE))
  src <- system.file(package = "etl", "src", "etl_template.R")
  dest <- file.path(path, "R", "etl.R")
  if (file.copy(src, dest)) {
    message("* Creating R/etl.R template source file...")
    readLines(dest) |>
      gsub("foo", pkg, x = _) |>
      writeLines(con = dest)
  }
#  usethis::use_package("etl", "Depends")
}
