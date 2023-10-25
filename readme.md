# Jai bindings for the International Components for Unicode library (ICU4C)

This module contains bindings and binaries for [icu4c](https://github.com/unicode-org/icu) v73.2.

I haven’t yet tested them on Linux and have made zero effort to prepare them for Windows.

## Usage

*Important:* You need to call `init_icu()` before calling any ICU functions to set the path to the ICU data file (located at `data/icudt73l.dat`).

See [example/example.jai](./example/example.jai) for how to convert between timezones, do date formatting, number formatting, ….
