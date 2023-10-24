AT_COMPILE_TIME :: true;

ICU_VERSION :: "73";

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
            array_add(*libpaths, "macos");
        } else {
            assert(false);
        }

        array_add(*libnames, "libicutu");
        array_add(*libnames, "libicuuc");
        array_add(*libnames, "libicui18n");
        array_add(*libnames, "libicudata");

        array_add(*include_paths, "./src");
        array_add(*source_files,  "unicode/ucal.h");
        array_add(*source_files,  "unicode/udat.h");
        array_add(*source_files,  "unicode/uloc.h");
        array_add(*source_files,  "unicode/unum.h");
        array_add(*source_files,  "unicode/ustring.h");
        array_add(*extra_clang_arguments, "-x", "c");

        // array_add(*generate_enums_from_macros_with_prefixes, "ULOC_");
        alias_original_enum_names = false;
        generate_library_declarations = false;

        visitor = icu_visitor;
        footer = FOOTER;
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

FOOTER :: #string END

#if OS == .MACOS {
    libicutu :: #library "macos/libicutu";
    libicuuc :: #library "macos/libicuuc";
    libicui18n :: #library "macos/libicui18n";
    libicudata :: #library "macos/libicudata";
}

END
