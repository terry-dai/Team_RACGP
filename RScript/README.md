Lachesis
====

~~~ {.bash}
lachesis.r -c FILENAME -a FILENAME -e FILENAME -l FILENAME [-o FILENAME]
~~~

Generates a roster that assigns assessors to cases in an exam matrix
and timetables candidates to cycle between assessors at a venue.

Valid filetypes are csv, xls and xlsx.

  Long option    | Short option | Description
  -----------    | ------------ | -----------
  `--candidates` | `-c` | Spreadsheet with candidate info.
  `--assessors`  | `-a` | Spreadsheet with assessor info.
  `--exams`      | `-e` | Spreadsheet with exam matrix info.
  `--locations`  | `-l` | Spreadsheet with venue info.
  `--session`    | `-s` | Choice of AM or PM session.
  `--rests`      | `-r` | Number of rest sessions (default 4).
  `--outfile`    | `-o` | Spreadsheet for storing final master roster.
  `--verbose`    | `-v` | Print debugging info to `stderr`.
  `--help`       | `-h` | Print this usage information.

If `--outfile` is not given, will output to `stdout`.


Dependencies
----

If you specify `xls` or `xlsx` files, the script will automatically install the Xlsx R package.
This in turn relies on having a
[64-bit Java runtime environment](http://java.com/en/download)
installed.

Furthermore, you may need to run `sudo R CMD javareconf`,
alter your Windows PATH environment variable,
or double-check that you are using 32-bit Java with 32-bit R,
or 64-bit Java with 64-bit R.

References:

* [R: rJava package install failing](http://stackoverflow.com/questions/3311940/r-rjava-package-install-failing)
* [Problems when trying to load a package in R due to rJava](http://stackoverflow.com/questions/17376939/problems-when-trying-to-load-a-package-in-r-due-to-rjava)
* [Using the rJava package on Win7 64 bit with R](http://stackoverflow.com/questions/7019912/using-the-rjava-package-on-win7-64-bit-with-r)
