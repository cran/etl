#' @rdname etl_create
#' @export
#' @examples
#' cars <- etl("mtcars")
#' # Do it step-by-step
#' cars |>
#'   etl_extract() |>
#'   etl_transform() |>
#'   etl_load()
#'
#' # Note the somewhat imprecise data types for the columns. These are the default.
#' tbl(cars, "mtcars")
#'
#' # But you can also specify your own schema if you want
#' schema <- system.file("sql", "init.sqlite", package = "etl")
#' cars |>
#'   etl_init(schema) |>
#'   etl_load()

etl_load <- function(obj, ...) UseMethod("etl_load")

#' @rdname etl_create
#' @export

etl_load.default <- function(obj, ...) {
  smart_upload(obj, ...)
  invisible(obj)
}

#' Upload a list of files to the DB
#' @param obj An [etl] object
#' @param src a list of CSV files to upload. If `NULL`, will return all
#' CSVs in the load directory
#' @param tablenames a list the same length as `src` of tablenames in the
#' database corresponding to each of the files in `src`. If `NULL`,
#' will default to the same name as `src`, without paths or file extensions.
#' @param ... arguments passed to [DBI::dbWriteTable()]
#' @export
#' @examples
#' \dontrun{
#' if (require(RMariaDB)) {
#'   # must have pre-existing database "fec"
#'   # if not, try
#'   system("mysql -e 'CREATE DATABASE IF NOT EXISTS fec;'")
#'   db <- src_mysql_cnf(dbname = "mtcars")
#' }
#' }
smart_upload <- function(obj, src = NULL, tablenames = NULL, ...) {
  if (is.null(src)) {
    src <- list.files(attr(obj, "load_dir"), pattern = "\\.csv", full.names = TRUE)
  }
  if (is.null(tablenames)) {
    tablenames <- basename(src) |>
      gsub("\\.csv", "", x = _)
  }
  if (length(src) != length(tablenames)) {
    warning("src and tablenames must be of the same length")
  }
  message(paste("Loading", length(src), "file(s) into the database..."))

  # write the tables directly to the DB
  mapply(DBI::dbWriteTable, name = tablenames, value = src,
         MoreArgs = list(conn = obj$con, append = TRUE, ... = ...))

  invisible(obj)
}



#' Initialize a database using a defined schema
#'
#' @param script either a vector of SQL commands to be executed, or
#' a file path as a character vector containing an SQL initialization script.
#' If `NULL` (the default), then the appropriate built-in
#' schema will be fetched by [find_schema(), if it exists. Note
#' that the flavor of SQL in this file must match the type of the source. That is,
#' if your object is of type [dplyr::src_mysql(), then make sure that
#' the schema you specify here is written in MySQL (and not PostgreSQL). Please
#' note that SQL syntax is not, in general, completely portable. Use with caution, as this may
#' clobber any existing data you have in an existing database.
#' @export
#' @examples
#' cars <- etl("mtcars")
#' cars |>
#'   etl_init()
#' cars |>
#'   etl_init(script = sql("CREATE TABLE IF NOT EXISTS mtcars_alt (id INTEGER);"))
#' cars |>
#'   etl_init(schema_name = "init")
#' init_script <- find_schema(cars, schema_name = "init")
#' cars |>
#'   etl_init(script = init_script, echo = TRUE)
#' src_tbls(cars)

etl_init <- function(obj, script = NULL, schema_name = "init",
                     pkg = attr(obj, "pkg"),
                     ext = NULL, ...) UseMethod("etl_init")

#' @rdname etl_init
#' @export
etl_init.default <- function(obj, script = NULL, schema_name = "init",
                             pkg = attr(obj, "pkg"), ext = NULL, ...) {
  obj <- verify_con(obj)

  if (is.character(script)) {
    schema <- script
  } else {
    schema <- find_schema(obj, schema_name, pkg, ext)
    if (is.null(schema)) {
      dbWipe(obj$con)
      return(invisible(obj))
    }
  }
  if (methods::is(obj$con, "DBIConnection")) {
    dbRunScript(obj$con, schema, ...)
  } else {
    stop("Invalid connection to database.")
  }
  invisible(obj)
}

#' @rdname etl_init
#'
#' @details If the table definitions are at all non-trivial,
#' you may wish to include a pre-defined table schema. This function
#' will retrieve it.
#'
#' @param obj An [etl] object
#' @param schema_name The name of the schema. Default is `init`.
#' @param pkg The package defining the schema. Should be set in [etl].
#' @param ext The file extension used for the SQL schema file. If NULL (the default) it
#' be inferred from the `src_*` class of `con`. For example, if `con`
#' has class [RSQLite::SQLite()] then `ext` will be `sqlite`.
#' @param ... Currently ignored
#' @export
#' @examples
#'
#' cars <- etl("mtcars")
#' find_schema(cars)
#' find_schema(cars, "init", "etl")
#' find_schema(cars, "my_crazy_schema", "etl")
#'
find_schema <- function(obj, schema_name = "init",
                        pkg = attr(obj, "pkg"), ext = NULL, ...) {
  if (is.null(ext)) {
    ext <- db_type(obj)
  }
  sql <- file.path("sql", paste0(schema_name, ".", ext))
  file <- system.file(sql, package = pkg, mustWork = FALSE)
  if (!file.exists(file)) {
    message("Could not find schema initialization script")
    return(NULL)
  }
  return(file)
}
