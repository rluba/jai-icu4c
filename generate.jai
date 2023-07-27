AT_COMPILE_TIME :: true;

ICU_VERSION :: "73";
#if OS == .MACOS {
    ICU4C_PATH :: "/usr/local/homebrew/Cellar/icu4c/73.2";
}

DECLARATIONS_TO_OMIT :: string.[
];

#if AT_COMPILE_TIME {
    #run {
        set_build_options_dc(.{do_output=false});
        if !generate_bindings() {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings() {
            exit(1);
        }
    }
}

generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            array_add(*libpaths,      "windows");
            output_filename          = "windows.jai";
        } else #if OS == .LINUX {
            // array_add(*libpaths,      "linux");
            output_filename          = "unix.jai";
            // generate_library_declarations = false;
        } else #if OS == .MACOS {
            // array_add(*libpaths,      "macos");
            output_filename          = "unix.jai";
            // generate_library_declarations = false;
            array_add(*include_paths, sprint("%/include", ICU4C_PATH));
            array_add(*libpaths, sprint("%/lib", ICU4C_PATH));
        } else {
            assert(false);
        }

        array_add(*libnames,      "libicutu");
        array_add(*libnames,      "libicuuc");
        array_add(*libnames,      "libicui18n");
        array_add(*libnames,      "libicudata");
        array_add(*source_files,  "unicode/ucal.h");
        array_add(*source_files,  "unicode/ustring.h");
        array_add(*extra_clang_arguments, "-x", "c");
        // auto_detect_enum_prefixes = false;
        // log_stripped_declarations = false;
        // generate_compile_time_struct_checks = false;
        // strip_flags |= .INLINED_FUNCTIONS; // "inline" functions are not present in the static library.

        visitor   = icu_visitor;
        // get_func_args_for_printing = imgui_get_function_arg_for_printing;
    }

    return generate_bindings(opts, output_filename);
}

enums_for_typedefs: Table(string, *Enum);

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";

icu_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    if !decl.parent && ends_with(decl.output_name, ICU_VERSION) {
        decl.output_name.count -= ICU_VERSION.count + 1; // Strip version suffix (eg. "_73")
    }

    return .RECURSE;
}
