context("etl")

test_that("sqlite works", {
  cars_sqlite <- etl("mtcars")
  expect_s3_class(cars_sqlite, c("etl_mtcars", "etl", "src_SQLiteConnection", "src_dbi", "src_sql"))
  expect_true(file.exists(find_schema(cars_sqlite)))
  expect_message(find_schema(cars_sqlite, "my_crazy_schema", "etl"))
  expect_output(summary(cars_sqlite), "files")
  expect_message(cars_sqlite |> etl_create(), "Loading")
  expect_message(cars_sqlite |> etl_init(), "SQL script")
  expect_message(
    cars_sqlite |> etl_cleanup(delete_raw = TRUE, delete_load = TRUE),
    "Deleting files")
  DBI::dbDisconnect(cars_sqlite$con)
})

test_that("default works", {
  dplyr_sqlite <- etl("dplyr")
  expect_s3_class(dplyr_sqlite, c("etl_dplyr", "etl", "src_SQLiteConnection", "src_dbi", "src_sql"))
  expect_output(summary(dplyr_sqlite), "files")
  expect_message(dplyr_sqlite |> etl_update(), "Loading")
  expect_message(
    dplyr_sqlite |> etl_cleanup(delete_raw = TRUE, delete_load = TRUE),
    "Deleting files")
  DBI::dbDisconnect(dplyr_sqlite$con)
})


test_that("dplyr works", {
  expect_message(cars <- etl("mtcars") |>
    etl_create(), regexp = "Loading")
  expect_gt(length(src_tbls(cars)), 0)
  tbl_cars <- cars |>
     tbl("mtcars")
  expect_s3_class(tbl_cars, "tbl_dbi")
  expect_s3_class(tbl_cars, "tbl_sql")
  res <- tbl_cars |>
    collect()
  expect_equal(nrow(res), nrow(mtcars))
  # double up the data
  expect_message(
    cars |>
      etl_update(), regexp = "Loading")
  res2 <- tbl_cars |>
    collect()
  expect_equal(nrow(res2), 2 * nrow(mtcars))
  DBI::dbDisconnect(cars$con)
})


test_that("MariaDB works", {
  if (require(RMariaDB) && mariadbHasDefault()) {
    db <- src_mysql_cnf()
    expect_s3_class(db, "src_dbi")
    cars_mysql <- etl("mtcars", db = db)
    expect_s3_class(cars_mysql, c("etl_mtcars", "etl", "src_dbi"))
    expect_true(file.exists(find_schema(cars_mysql)))
    expect_message(find_schema(cars_mysql, "my_crazy_schema", "etl"))
    expect_output(summary(cars_mysql), "/tmp")
    dbDisconnect(db)
  }
})


test_that("valid_year_month works", {
  dates <- valid_year_month(years = 1999:2001, months = c(1:3, 7))
  expect_is(dates, "tbl_df")
  expect_equal(nrow(dates), 12)
})

test_that("extract_date_from_filename works", {
  test <- expand.grid(year = 1999:2001, month = c(1:6, 9)) |>
    mutate(filename = paste0("myfile_", year, "_", month, ".csv"))
  expect_is(
    extract_date_from_filename(test$filename, pattern = "myfile_%Y_%m.csv"),
    "Date"
  )
  expect_null(extract_date_from_filename(list.files("/cdrom"), pattern = "*"))

  files <- fs::path(tempdir(), test$filename)
  lapply(files, FUN = readr::write_csv, x = data.frame(var = "etl"))

  res <- match_files_by_year_months(
    files,
    pattern = "myfile_%Y_%m.csv", year = 1999:2000
  )
  expect_is(res, "fs_path")
  expect_length(res, 14)
})

test_that("etl works", {
  expect_error(etl("willywonka"), "Please make sure that")
  expect_message(
    etl("mtcars", dir = file.path(tempdir(), "etltest")), "etltest")
  cars <- etl("mtcars")
  expect_true(is.etl(cars))
  expect_output(print(cars), "sqlite")
  DBI::dbDisconnect(cars$con)
})

test_that("smart_download works", {
  skip_on_cran()
  cars <- etl("mtcars")
  # first download some files
#  if (!.Platform$OS.type == "windows") {
  expect_message(etl_cleanup(cars, pattern = ".", delete_raw = TRUE, delete_load = TRUE), "Deleting")
  urls <- c("https://raw.githubusercontent.com/beanumber/etl/master/etl.Rproj",
            "https://www.reddit.com/robots.txt")
  expect_length(smart_download(cars, src = urls), 2)
  # then try to download them again
  expect_length(smart_download(cars, src = urls), 0)
  expect_message(etl_cleanup(cars, pattern = ".", delete_raw = TRUE, delete_load = TRUE), "Deleting")
  #  }
  DBI::dbDisconnect(cars$con)
})


test_that("cities works", {
  skip_on_cran()
  cities_sqlite <- etl("cities")
  # fails on check() but not on test()?? issue #37
#   expect_message(cities_sqlite |> etl_create(), "Loading")
  expect_message(
    cities_sqlite |> etl_cleanup(delete_raw = TRUE, delete_load = TRUE),
    "Deleting files")
  DBI::dbDisconnect(cities_sqlite$con)
})



test_that("create ETL works", {
  path <- file.path(tempdir(), "scorecard")
  expect_output(create_etl_package(path, open = FALSE), "Package")
})

test_that("dbRunScript works", {
  sql <- "SHOW TABLES; SELECT 1+1 as Two;"

  if (require(RSQLite)) {
     con <- dbConnect(RSQLite::SQLite())
     expect_equal(0, sum(unlist(dbRunScript(con, "SELECT 1+1 as Two; VACUUM; ANALYZE;"))))
     init_sqlite <- system.file("sql", "init.sqlite", package = "etl")
     expect_equal(0, sum(unlist(dbRunScript(con, script = init_sqlite))))
     dbDisconnect(con)
  }
  if (require(RMariaDB) && mariadbHasDefault()) {
    db <- src_mysql_cnf()
    expect_equal(-2, sum(unlist(dbRunScript(db$con, script = sql))))
    init_mysql <- system.file("sql", "init.mysql", package = "etl")
    expect_equal(0, sum(unlist(dbRunScript(db$con, script = init_mysql))))
    expect_true("mtcars" %in% DBI::dbListTables(db$con))
    dbDisconnect(db$con)
  }
})

