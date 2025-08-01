# etl 0.4.2 (2025-07-24)

* Switched to base pipe
* Replaced RMySQL with RMariaDB
* Converted documentation to Markdown

# etl 0.4.1 (2023-10-12)

* Added call to `dbplyr::src_dbi()` in `verify_con()` to workaround new `dplyr` behavior; #60
* Complete transition to GitHub Actions

# etl 0.4.0 (2020-06-02)

* Removed `stringr` dependency
* Remove `LazyData: TRUE` since there is no data
* Don't run examples that use the Internet

# etl 0.3.9 (2020-06-01)

* Fixed issue with new version of `usethis`; #59
* Cleaned up NAMESPACE
* Removed `macleish` dependency
* Removed `airlines` mentions in vignettes

### MINOR IMPROVEMENTS

# etl 0.3.8 (2019-12-18)

### MINOR IMPROVEMENTS

* Added `create_etl_package` function for rapid prototyping
* `dbRunScript` is robust to comments generated by `mysqldump`

# etl 0.3.7 (2017-09-25)

### MINOR IMPROVEMENTS

* Added `etl_cities` methods
* Added `default` methods for any package
* Added "Extending ETL" vignette

# etl 0.3.6 (2017-07-20)

### MINOR IMPROVEMENTS

* Added `clobber` option to `smart_download`
* Added `db_type` for easy typing of connection objects
* Added `smart_upload` for pushing files to database
* Added `dbplyr` to Suggests
* Fixed broken link to `dplyr::src_sql` in documentation

# etl 0.3.5 (2016-11-28)

### MINOR IMPROVEMENTS

* Fixed CRAN failures on Solaris (thanks Brian Ripley)

# etl 0.3.4 (2016-11-07)

### MINOR IMPROVEMENTS

* Added `src_mysql_cnf` as shorthand for connecting to MySQL
* Fixed CRAN failures on Solaris (thanks Brian Ripley)
* Moved to `file.path` uniformly (#7)
* Moved `smart_download` to `downloader` for HTTPS

# etl 0.3.3 (2016-07-27)

### MINOR IMPROVEMENTS

* Moved `is.etl` to main documentation for `etl` (30dee378)
* Fixed typo in DESCRIPTION (4e77fba2)
* Fixed bug in `etl_load.etl_mtcars` by making `etl_transform` safer
* Made `verify_con` messages easier to read
* Added new functions for help with computing dates and matching filenames to dates
* Added several tests
* Added `new_filenames` argument to `smart_download`
* Re-implemented `etl_init` (#7)
* Renamed `get_schema` to `find_schema` (1c0a4e3)

# etl 0.3.1 (2016-06-07)

### NEW FEATURES

* released to CRAN
* Added a `NEWS.md` file to track changes to the package.



