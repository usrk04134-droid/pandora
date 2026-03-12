version_numbers = strsplit(getversion(),["-","."]);
supported_version = 2026;
if evstr(version_numbers(2)) < supported_version then
    disp("Scilab version must be >= 2026.*.*, aborting.")
end

// Some defaults
file_path = "";
plot_settings = struct("n_colors", 64,..
    "stickout", 25e-3,..
    "current_max", 850,..
    "current_min", 650,..
    "speed_max", 95 /(100*60),..
    "speed_min", 80 /(100*60),..
    "time_min", "",...
    "time_max", "",...
    "zoom_box", [-0.05,0.9627521,0.05,1.01,-1,1],..
    "log_file", file_path,...
    "nbr_samples_per_rev", 100,...
    "nbr_beads_to_show", 0,...
    "macs_to_rocs_translation", [-142.42e-3; -89.6e-3; -2211.5e-3],...
    "log_type", "test log",...
    "quit_on_close", %f);

// Check for passed args, use if present and valid
quit_on_close = %f;
all_args = sciargs();
disp(all_args)
path_to_src = fileparts(all_args(4), "path");
cd(path_to_src);

k = find(all_args == "-args"); //Find beginning of script args
for i = [(k+1):size(all_args,1)]
    arg_parts = strsplit(all_args(i), ["="]);
    select arg_parts(1)
        case "--quit-on-close"
          quit_on_close = %t;
        case "--stickout"
            plot_settings.stickout = evstr(arg_parts(2));
        case "--current_min"
            plot_settings.current_min = evstr(arg_parts(2));
        case "--current_max"
            plot_settings.current_max = evstr(arg_parts(2));
        case "--speed_min"
          plot_settings.speed_min = evstr(arg_parts(2));
        case "--speed_max"
          plot_settings.speed_max = evstr(arg_parts(2));
        case "--nbr_samples"
          plot_settings.nbr_samples_per_rev = evstr(arg_parts(2)); //Only matters for weld control log
        case "--macs_rocs_translation"
          try
            plot_settings.macs_to_rocs_translation = evstr(arg_parts(2));
          catch
            disp("Failed to evalutate translation vector. Is format wrong? Falling back to default.")
          end
    end
end

// Load dependencies
exec("profile_matching.sci", -1);
exec("adaptivity_ui.sci", -1);
exec("adaptivity_functions.sci", -1);


// Init UI
fig  = InitPlotWindow(plot_settings);
fig.user_data.plot_settings = plot_settings;
if quit_on_close
    fig.closerequestfcn = "quit";
    fig.user_data.quit_on_close = %t;
end




