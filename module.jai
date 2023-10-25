DEFAULT_ICU_DATA :: #run sprint("%/data", #filepath);

init_icu :: (path_to_data := DEFAULT_ICU_DATA) {
    u_setDataDirectory(temp_c_string(path_to_data));
}

// The result will be zero-terminated but the zero is _not_ included in the count.
utf16_from_utf8 :: (str: string) -> result: [] u16, success: bool {
    if !str return .[], true;

    assert(str.count <= Math.S32_MAX);
    status := UErrorCode.ZERO_ERROR;
    preflight_w_count: s32;
    u_strFromUTF8(null, 0, *preflight_w_count, str.data, cast(s32) str.count, *status);
    assert(status == .BUFFER_OVERFLOW_ERROR);
    assert(preflight_w_count > 0);

    status = UErrorCode.ZERO_ERROR;
    w_str := NewArray(preflight_w_count + 1, UChar, initialized = false); // + 1 for zero-termination
    w_size: s32;
    u_strFromUTF8(w_str.data, cast(s32) w_str.count, *w_size, str.data, cast(s32) str.count, *status);
    if status != .ZERO_ERROR {
        log_error("Could not convert \"%\" to UTF16: %", str, status);
        return .[], false;
    }
    assert(w_size == preflight_w_count);
    w_str.count -= 1; // Don’t include the zero in the count.
    return w_str, true;
}

// The result will be zero-terminated but the zero is _not_ included in the count.
utf8_from_utf16 :: (w_str: [] u16) -> result: string, success: bool {
    if !w_str return "", true;

    assert(w_str.count <= Math.S32_MAX);
    status := UErrorCode.ZERO_ERROR;
    preflight_count: s32;
    u_strToUTF8(null, 0, *preflight_count, w_str.data, cast(s32) w_str.count, *status);
    assert(status == .BUFFER_OVERFLOW_ERROR);
    assert(preflight_count > 0);

    status = UErrorCode.ZERO_ERROR;
    str := cast(string) NewArray(preflight_count + 1, u8, initialized = false); // + 1 for zero-termination
    size: s32;
    u_strToUTF8(str.data, cast(s32) str.count, *size, w_str.data, cast(s32) w_str.count, *status);
    if status != .ZERO_ERROR {
        log_error("Could not convert % from UTF16: %", w_str, status);
        return "", false;
    }
    assert(size == preflight_count);
    str.count -= 1; // Don’t include the zero in the count.
    return str, true;
}

format_date :: (format: *UDateFormat, date: Apollo_Time) -> string, success: bool {
    result, success := format_date(format, cast(UDate) to_milliseconds(date - APOLLO_TIME_FOR_JAN_1_1970));
    return result, success;
}

format_date :: (format: *UDateFormat, date: UDate) -> string, success: bool {
    status := UErrorCode.ZERO_ERROR;
    preflight_count := udat_format(format, date, null, 0, null, *status);
    assert(status == .BUFFER_OVERFLOW_ERROR);

    status = .ZERO_ERROR;
    buffer := NewArray(preflight_count + 1, u16, initialized = false, allocator = temp); // + 1 for zero-termination
    count := udat_format(format, date, buffer.data, cast(s32) buffer.count, null, *status);
    if status != .ZERO_ERROR {
        log_error("Could not format date %: %", date, status);
        return "", false;
    }

    assert(count == preflight_count);

    result_utf16 := array_view(buffer, 0, count);
    result_string, success := utf8_from_utf16(result_utf16);
    assert(success);
    return result_string, success;
}

format_float64 :: (format: *UNumberFormat, value: float64) -> string, success: bool {
    status := UErrorCode.ZERO_ERROR;
    preflight_count := unum_formatDouble(format, value, null, 0, null, *status);
    assert(status == .BUFFER_OVERFLOW_ERROR);

    status = .ZERO_ERROR;
    buffer := NewArray(preflight_count + 1, u16, initialized = false, allocator = temp); // + 1 for zero-termination
    count := unum_formatDouble(format, value, buffer.data, cast(s32) buffer.count, null, *status);
    if status != .ZERO_ERROR {
        log_error("Could not format number %: %", value, status);
        return "", false;
    }

    assert(count == preflight_count);

    result_utf16 := array_view(buffer, 0, count);
    result_string, success := utf8_from_utf16(result_utf16);
    assert(success);
    return result_string, success;
}

is_format_success :: (status: UErrorCode) -> bool {
    // For some reason, we ALWAYS get USING_DEFAULT_WARNING when calling unum_open(), even when it seems to work!?
    return status == .ZERO_ERROR || status == .USING_DEFAULT_WARNING;
}

#if OS == .WINDOWS {
} else {
    #load "unix.jai";
}
#scope_module
wchar_t :: u16;

Math :: #import "Math"; // FOr S32_MAX, which shouldn’t be in Math…
