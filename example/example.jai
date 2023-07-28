main :: () {
    time_in_timezone_to_utc();
    serial_in_timezone_to_utc();
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

#import "Basic";
#import,file "../module.jai";

#scope_file

// This is currently still in #scope_file in Apollo_Time, so let’s define it locally until that’s changed.
APOLLO_TIME_FOR_JAN_1_1970 :: Apollo_Time.{low=0xdbd87f0edb7c8000, high=0x300};
