#run {
    set_build_options_dc(.{do_output = false});

    w := compiler_create_workspace("Example");
    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);
    options.additional_linker_arguments = .["-lc++"];
    options.output_executable_name = "example";
    set_build_options(options, w);

    add_build_file("example.jai", w);
};

#import "Basic";
#import "Compiler";
