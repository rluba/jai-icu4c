main :: () {
    utf_roundtrip();
    available_locales();
    time_in_timezone_to_utc();
    serial_in_timezone_to_utc();
    number_formats();
    date_formats();
}

utf_roundtrip :: () {
    original := "Hello, Sailor!";
    utf16_string, success := utf16_from_utf8(original);
    assert(success);
    log("UTF-16 version of \"%\" is %", original, utf16_string);
    utf8_string, success= := utf8_from_utf16(utf16_string);
    assert(success);
    log("Converted back to UTF-8: \"%\"", utf8_string);
    assert(utf8_string == original);
}

available_locales :: () {
    default_locale := uloc_getDefault();
    log("Default locale: %", to_string(default_locale));

    count := uloc_countAvailable();
    for i: 0..count-1 {
        locale := uloc_getAvailable(i);
        log("Locale %: %", i, to_string(locale));
    }
}

time_in_timezone_to_utc :: () {
    timezone := "Europe/Vienna";
    timezone_w, success := utf16_from_utf8(timezone);
    if !success exit(1);

    status := UErrorCode.ZERO_ERROR;
    local_cal := ucal_open(timezone_w.data, cast(s32) timezone_w.count, null, .GREGORIAN, *status);
    if status != .ZERO_ERROR {
        log_error("Could not open calendar for timezone \"%\": %", timezone, status);
        exit(1);
    }

    ucal_set(local_cal, .YEAR,        2023);
    ucal_set(local_cal, .MONTH,       6); // zero-based! Because footguns are fun…
    ucal_set(local_cal, .DATE,        27);
    ucal_set(local_cal, .HOUR_OF_DAY, 15);
    ucal_set(local_cal, .MINUTE,      0);
    ucal_set(local_cal, .SECOND,      0);

    // Convert the timestamp to UTC by getting the UTC time in milliseconds since epoch
    ms_since_unix_epoch_start := ucal_getMillis(local_cal, *status);
    if status != .ZERO_ERROR {
        log_error("Could not get milliseconds from calendar for timezone \"%\": %", timezone, status);
        exit(1);
    }

    log("milliseconds since epoch start: %", ms_since_unix_epoch_start);

    apollo_time := APOLLO_TIME_FOR_JAN_1_1970 + milliseconds_to_apollo(cast(s64) ms_since_unix_epoch_start);
    apollo_cal := to_calendar(apollo_time);
    log("as an apollo calendar: %", apollo_cal);
}

serial_in_timezone_to_utc :: () {
    us_time := 1684161000000000; // µs from unix epoch start until 2023-05-15T14:30:00 (in UTC, but we will treat it as a local time in a different timezone)
    timezone := "Europe/Vienna";
    timezone_w, success := utf16_from_utf8(timezone);
    if !success exit(1);

    status := UErrorCode.ZERO_ERROR;
    local_cal := ucal_open(timezone_w.data, cast(s32) timezone_w.count, null, .GREGORIAN, *status);
    if status != .ZERO_ERROR {
        log_error("Could not open calendar for timezone \"%\": %", timezone, status);
        exit(1);
    }

    local_apollo_time := APOLLO_TIME_FOR_JAN_1_1970 + microseconds_to_apollo(us_time);
    local_apollo_cal := to_calendar(local_apollo_time);
    log("Local apollo cal: %", local_apollo_cal);

    ucal_set(local_cal, .YEAR,        local_apollo_cal.year);
    ucal_set(local_cal, .MONTH,       local_apollo_cal.month_starting_at_0); // zero-based! Because footguns are fun…
    ucal_set(local_cal, .DATE,        local_apollo_cal.day_of_month_starting_at_0 + 1);
    ucal_set(local_cal, .HOUR_OF_DAY, local_apollo_cal.hour);
    ucal_set(local_cal, .MINUTE,      local_apollo_cal.minute);
    ucal_set(local_cal, .SECOND,      local_apollo_cal.second);
    ucal_set(local_cal, .MILLISECOND, local_apollo_cal.millisecond);

    // Convert the timestamp to UTC by getting the UTC time in milliseconds since epoch
    ms_since_unix_epoch_start := ucal_getMillis(local_cal, *status);
    if status != .ZERO_ERROR {
        log_error("Could not get milliseconds from calendar for timezone \"%\": %", timezone, status);
        exit(1);
    }

    log("milliseconds since epoch start: %", ms_since_unix_epoch_start);


    apollo_time := APOLLO_TIME_FOR_JAN_1_1970 + milliseconds_to_apollo(cast(s64) ms_since_unix_epoch_start);
    apollo_cal := to_calendar(apollo_time);
    log("as an apollo calendar: %", apollo_cal);
}

number_formats :: () {
    do_locale :: (locale: string) {
        open_format :: (style: UNumberFormatStyle) -> *UNumberFormat #expand {
            status := UErrorCode.ZERO_ERROR;
            result := unum_open(style, null, 0, temp_c_string(locale), null, *status);
            if !is_format_success(status) {
                log_error("Could not open % number format \"%\": %", style, locale, status);
                exit(1);
            }

            return result;
        }

        decimal_format := open_format(.DECIMAL);
        currency_format := open_format(.CURRENCY);
        percent_format := open_format(.PERCENT);
        defer unum_close(decimal_format);
        defer unum_close(currency_format);
        defer unum_close(percent_format);

        number := 42.123;
        decimal, success := format_float64(decimal_format, number);
        assert(success);
        currency, success= := format_float64(currency_format, number);
        assert(success);
        // Careful: percent formatting assumes that 1.00 == 100%!!
        percent, success= := format_float64(percent_format, number);
        assert(success);
        log("% formatted for \"%\" is \"%\", \"%\", \"%\"", number, locale, decimal, currency, percent);
    }

    do_locale("en_US");
    do_locale("de_AT");
    do_locale("de_AT@currency=USD"); // AT, but with a custom currency
    do_locale("cs_CZ");
}

date_formats :: () {
    do_locale :: (time: Apollo_Time, locale: string, date_style: UDateFormatStyle, time_style: UDateFormatStyle) {
        status := UErrorCode.ZERO_ERROR;
        date_format := udat_open(time_style, date_style, temp_c_string(locale), null, 0, null, 0, *status);
        if status != .ZERO_ERROR {
            log_error("Could not open date format \"%\": %", locale, status);
            exit(1);
        }

        defer udat_close(date_format);

        udate := cast(UDate) to_milliseconds(time - APOLLO_TIME_FOR_JAN_1_1970);

        result, success := format_date(date_format, udate);
        assert(success);
        log("\"%\" formatted for \"%\" is \"%\"", calendar_to_iso_string(to_calendar(time)), locale, result);
    }

    now := current_time_consensus();
    do_locale(now, "en_US", .FULL, .FULL);
    do_locale(now, "en_US", .SHORT, .SHORT);
    do_locale(now, "de_AT", .FULL, .FULL);
    do_locale(now, "de_AT", .SHORT, .SHORT);

    time := calendar_to_apollo(Calendar_Time.{year = 2001, month_starting_at_0 = 9, day_of_month_starting_at_0 = 23});
    formats := UDateFormatStyle.[.FULL, .LONG, .MEDIUM, .SHORT, .DEFAULT, .RELATIVE, .MEDIUM_RELATIVE];
    for formats {
        do_locale(time, "en_US", it, .NONE);
        do_locale(time, "de_AT", it, .NONE);
    }
}

#import "Basic";
#import,file "../module.jai";

#scope_file

// This is currently still in #scope_file in Apollo_Time, so let’s define it locally until that’s changed.
APOLLO_TIME_FOR_JAN_1_1970 :: Apollo_Time.{low=0xdbd87f0edb7c8000, high=0x300};
