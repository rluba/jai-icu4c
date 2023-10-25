AT_COMPILE_TIME :: true;

COMPILE         :: true;       // Enable to compile the library from source before generating bindings.

ICU_PATH        :: "icu-73.2"; // Path to the source, not included in this repo.
ICU_VERSION     :: "73";       // For stipping identifier suffixes and for patching the dylib rpaths on macOS

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
    #if COMPILE {
		success := build_icu();
		if !success return false;
	}

    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            output_filename         = "windows.jai";
            array_add(*libpaths,      "windows/lib");
            array_add(*include_paths, "windows/include");
        } else #if OS == .LINUX {
            output_filename         = "unix.jai";
            array_add(*libpaths,      "linux/lib");
            array_add(*include_paths, "linux/include");
        } else #if OS == .MACOS {
            output_filename         = "unix.jai";
            array_add(*libpaths,      "macos/lib");
            array_add(*include_paths, "macos/include");
        } else {
            assert(false);
        }

        array_add(*libnames, "libicudata");
        array_add(*libnames, "libicuuc");
        array_add(*libnames, "libicui18n");
        array_add(*libnames, "libicutu");

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

#if OS == .LINUX {
    CONFIG_NAME :: "Linux";
    PLATFORM_NAME :: "linux";
} else #if OS == .MACOS {
    CONFIG_NAME :: "MacOSX";
    PLATFORM_NAME :: "macos";
} else {
    compiler_report(tprint("Unsupported platform: %", OS));
}

build_icu :: () -> bool {
	install_dir := PLATFORM_NAME;
    success := make_directory_if_it_does_not_exist(install_dir);
    if !success {
        log_error("Could not create directory \"%\"\n", install_dir);
		return false;
    }

	absolute_install_dir := get_absolute_path(install_dir);
	assert(absolute_install_dir != "");

    absolute_build_dir := join(absolute_install_dir, "_build");
    log("Configuring icu... \"%\" -> \"%\"", absolute_build_dir, absolute_install_dir);
	if file_exists(absolute_build_dir) {
		success := delete_directory(absolute_build_dir);
		if !success {
			log_error("Could not delete old build directory");
			return false;
		}
	}
    success = make_directory_if_it_does_not_exist(absolute_build_dir);
    if !success {
        log_error("Could not create directory \"%\"\n", absolute_build_dir);
		return false;
    }

    #if OS == .MACOS {
        options := get_build_options();
        macos_version_arg := tprint("-mmacosx-version-min=%.%\0", options.minimum_macos_version.major, options.minimum_macos_version.minor);
        setenv("CFLAGS", macos_version_arg.data, 1);
        setenv("CXXFLAGS", macos_version_arg.data, 1);
        // setenv("LDFLAGS", tprint("-install_name @rpath/%", exe_path), 1);
    }

    // Set all the recommended stuff:
    setenv("CPPFLAGS", "-DU_NO_DEFAULT_INCLUDE_UTF_HEADERS -DU_HIDE_OBSOLETE_UTF_OLD_H", 1);

	absolute_icu_path := get_absolute_path(ICU_PATH);
    config_command: [..] string;
    array_add(*config_command,
        tprint("%/source/runConfigureICU", absolute_icu_path),
        CONFIG_NAME,
        tprint("--prefix=%", absolute_install_dir),
        "--enable-static",               // Also build a static library
        "--with-data-packaging=archive", // Save the ICU data in a separate file instead of building it into every library. This then requires an inital call to u_setDataDirectory() mandatory.
	);

    run_or_exit(..config_command, working_directory = absolute_build_dir);
    log("Done configuring icu");

    log("Building icu…");
    build_command: [..] string;
    array_add(*build_command, "make", "install");
    run_or_exit(..build_command, working_directory = absolute_build_dir);
	log("Done building icu");

    #if OS == .MACOS {
        log("Patching library paths…");
        library_names := string.[
            tprint("libicuuc.%.dylib", ICU_VERSION),
            tprint("libicudata.%.dylib", ICU_VERSION),
            tprint("libicutu.%.dylib", ICU_VERSION),
            tprint("libicui18n.%.dylib", ICU_VERSION),
        ];
        for lib: library_names {
            path := tprint("macos/lib/%", lib);
            args: [..] string;
            array_add(*args, "install_name_tool");
            for library_names {
                if it == lib continue;
                array_add(*args, "-change", it, tprint("@loader_path/%", it));
            }
            array_add(*args,
                "-id", tprint("@rpath/%", lib),
                tprint("macos/lib/%", lib),
            );
            run_or_exit(..args);
        }
        log("Done patching @rpath");
    }

	return true;
}

run_or_exit :: (command: .. string, working_directory := "") -> string {
    // Enable this to see the commands being executed.
    // Might be useful if, for example, you need to compile LLVM on a platform where we don’t have a Jai compiler yet and want to do it manually.
    // log("Executing command \"%\" in directory \"%\"\n", join(..command, separator = " "), working_directory);

    result, output_string, error_string := run_command(..command, working_directory = working_directory, capture_and_return_output = true, print_captured_output = true);
    defer {
        free(error_string);
    }
    if result.exit_code != 0 {
        log_error("Could not run command \"%\" in directory \"%\". Exit code: %\nError:\n%", get_quoted_command_string(command), working_directory, result.exit_code, error_string);
        // if !LIVE_OUTPUT {
        //     log_error("Output:\n%", output_string);
        // }
        exit(1);
    }
    return output_string;
}



icu_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    if !decl.parent && ends_with(decl.output_name, ICU_VERSION) {
        decl.output_name.count -= ICU_VERSION.count + 1; // Strip version suffix (eg. "_73")
    }

    return .RECURSE;
}

FOOTER :: #string END

#if OS == .MACOS {
    libicudata :: #library "macos/lib/libicudata";
    libicuuc :: #library "macos/lib/libicuuc";
    libicui18n :: #library "macos/lib/libicui18n";
    libicutu :: #library "macos/lib/libicutu";
}

END

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Hash_Table";
#import "POSIX";
#import "Process";
#import "String";

