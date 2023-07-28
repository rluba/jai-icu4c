
// The result will be zero-terminated but the zero is _not_ included in the count.
utf16_from_utf8 :: (str: string) -> result: [] u16, success: bool {
    if !str return .[], true;

    assert(str.count <= Math.S32_MAX);
    status := UErrorCode.ZERO_ERROR;
    w_size_preflight: s32;
    u_strFromUTF8(null, 0, *w_size_preflight, str.data, cast(s32) str.count, *status);
    assert(status == .BUFFER_OVERFLOW_ERROR);
    assert(w_size_preflight > 0);

    status = UErrorCode.ZERO_ERROR;
    w_str := NewArray(w_size_preflight + 1, UChar, initialized = false); // + 1 for zero-termination
    w_size: s32;
    u_strFromUTF8(w_str.data, cast(s32) w_str.count, *w_size, str.data, cast(s32) str.count, *status);
    if status != .ZERO_ERROR {
        log_error("Could not convert \"%\" to UTF16: %", str, status);
        return .[], false;
    }
    assert(w_size == w_size_preflight);
    w_str.count -= 1; // Don’t include the zero in the count.
    return w_str, true;
}

#if OS == .WINDOWS {
} else {
    #load "unix.jai";
}
#scope_module
wchar_t :: u16;

Math :: #import "Math"; // FOr S32_MAX, which shouldn’t be in Math…
