main :: () {
    timezone := "Europe/Vienna";
    status := UErrorCode.ZERO_ERROR;
    buffer: [100] UChar;
    timezone_w_size: s32;
    u_strFromUTF8(buffer.data, buffer.count, *timezone_w_size, timezone.data, cast(s32) timezone.count, *status);
    if status != .ZERO_ERROR {
        log_error("Could not convert \"%\" to wide: %", timezone, status);
        exit(1);
    }
    timezone_w := array_view(buffer, 0, timezone_w_size);

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

#import "Basic";
#import,file "../module.jai";
