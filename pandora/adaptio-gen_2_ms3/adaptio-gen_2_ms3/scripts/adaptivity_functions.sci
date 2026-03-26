
function [test_cases] = FindTestCasesInFile(file_path)
    test_cases = [];
    os_name = getos();
    command_text = "";
    
    // Find the rows where test cases are started
    if os_name == "Linux"
        command_text = msprintf("grep -n ""Starting test:"" %s", file_path);
    elseif os_name == "Windows"
        command_text = msprintf("powershell -Command ""Select-String -Pattern ''Starting test:'' -Path ''%s'' | ForEach-Object {\\""$($_.LineNumber): $($_.Line )\\""}""", file_path);
    end

    [status, testcase_rows, stderr] = host(command_text);
    
    if testcase_rows == ""
        return;
    end

    // Find the rows where sub-cases are started
    if os_name == "Linux"
        command_text = msprintf("grep -n ""Subcase:"" %s", file_path);
    elseif os_name == "Windows"
        command_text = msprintf("powershell -Command ""Select-String -Pattern ''Subcase:'' -Path ''%s'' | ForEach-Object {\\""$($_.LineNumber): $($_.Line )\\""}""", file_path);
    end

    [status, subcase_rows, stderr] = host(command_text);

    test_case_idx = 1;
    for i = 1:size(testcase_rows,1)
        test_case_parts = strsplit(testcase_rows(i),":");
        test_case_name = test_case_parts(5);
        test_case_start = evstr(test_case_parts(1));
        has_sub_cases = %f;

        // Check if there are subcases of this testcase
        if subcase_rows <> ""
            for j = 1:size(subcase_rows,1)
                sub_case_parts = strsplit(subcase_rows(j),":");
                sub_case_parent_name = sub_case_parts(5);
                sub_case_name = sub_case_parts(7);
                sub_case_start = evstr(sub_case_parts(1));

                if sub_case_parent_name == test_case_name
                    test_cases(test_case_idx) = struct("start_row", sub_case_start,...
                                                      "end_row", %inf,...
                                                      "test_name", test_case_name + "::" + sub_case_name);
                    
                    test_case_idx = test_case_idx + 1;
                    has_sub_cases = %t;               
                                      
                end
            
            end
        end
        // No subcases --> use test case itself
        if ~has_sub_cases
            test_cases(test_case_idx) = struct("start_row", test_case_start,...
                                               "end_row", %inf,...
                                               "test_name", test_case_name);
            test_case_idx = test_case_idx + 1;
        end                                   
    end

    // Assign end row of each test case in file
    for i = 1:length(test_cases)-1
        test_cases(i).end_row = test_cases(i+1).start_row;
    end
    
endfunction

function [new_profile] = AddBackSideToProfile(profile)

    thickness = 150e-3;
    width = profile(1).x - profile($).x;
    new_profile = profile;
    n_points = length(profile);
    new_profile(n_points + 1) = struct("x", new_profile(n_points).x, "y", 0, "z", new_profile(n_points).z - thickness);
    new_profile(n_points + 2) = struct("x", new_profile(1).x , "y", 0, "z", new_profile(n_points).z - thickness);

endfunction

function [new_points] = ConvertPointsFromMmToM(points)

    new_points = [];
    for i = 1:length(points)
        new_points(i).x = points(i).x * 1e-3;
        new_points(i).y = points(i).y * 1e-3;
        new_points(i).z = points(i).z * 1e-3;
    end

endfunction

function [points_rocs] = ConvertPointsFromMacsToRocs(points_macs, macs_to_rocs_translation)

    // TODO: For now this will only be the translation part, but the rotation 
    // could be added later by using calibration data and the position from weldcontrol log
    // The full transformation would be needed for full accuracy.
    points_rocs = [];
    for i = 1:length(points_macs)
        points_rocs(i).x = points_macs(i).x - macs_to_rocs_translation(1);
        points_rocs(i).y = points_macs(i).y - macs_to_rocs_translation(2);
        points_rocs(i).z = points_macs(i).z - macs_to_rocs_translation(3);  
    end

endfunction

function [slices] = RectifySlices(slices, nbr_samples_per_rev, waitbar_handle)
    stickout = 25e-3; // TODO: Pass this in. Take from UI.
    slice_count = 0;
    nbr_slices = length(slices);
    for sample_idx = 0 : nbr_samples_per_rev - 1
        waitbar(sample_idx/nbr_samples_per_rev, "Matching profiles", waitbar_handle);  
        slice_count = slice_count + 1;
        k_slices = find(list2vec(slices.slice_sample_index) == sample_idx);
        n_slices_at_position = length(k_slices); 
        for i = 2:n_slices_at_position
            
            curr_idx = k_slices(i);
            prev_idx = k_slices(i-1);
            
            src_abw = [list2vec(slices(curr_idx).abw_points.x),list2vec(slices(curr_idx).abw_points.z)];
            ref_abw = [list2vec(slices(prev_idx).abw_points.x),list2vec(slices(prev_idx).abw_points.z)];
            src_profile = [list2vec(slices(curr_idx).slice_points_rocs.x),list2vec(slices(curr_idx).slice_points_rocs.z)];
            ref_profile = [list2vec(slices(prev_idx).slice_points_rocs.x),list2vec(slices(prev_idx).slice_points_rocs.z)];
            wire_tip_pos = [slices(curr_idx).torch_pos_rocs.x, slices(curr_idx).torch_pos_rocs.z - stickout];

            [new_profile, new_abw, new_wire_tip_pos] = MatchProfiles(src_abw, src_profile, ref_abw, ref_profile, wire_tip_pos);
            
            // Update the src (current) slice
            // Assume that all points have the same y, and keep that after rectification
            y_to_keep = slices(curr_idx).slice_points_rocs(1).y;
            slices(curr_idx).slice_points_rocs = [];
            for j = 1:size(new_profile,1)
                slices(curr_idx).slice_points_rocs(j) = struct("x", new_profile(j,1),...
                                                               "y", y_to_keep,...
                                                               "z", new_profile(j,2));
            end
            slices(curr_idx).abw_points(1).x = new_abw(1,1);
            slices(curr_idx).abw_points(1).z = new_abw(1,2);
            slices(curr_idx).abw_points(2).x = new_abw(2,1);
            slices(curr_idx).abw_points(2).z = new_abw(2,2);
            slices(curr_idx).abw_points(6).x = new_abw(6,1);
            slices(curr_idx).abw_points(6).z = new_abw(6,2);
            slices(curr_idx).abw_points(7).x = new_abw(7,1);
            slices(curr_idx).abw_points(7).z = new_abw(7,2);

            slices(curr_idx).torch_pos_rocs.x = new_wire_tip_pos(1);            
            slices(curr_idx).torch_pos_rocs.z = new_wire_tip_pos(2) + stickout;
        end
    end

    for i = 1:length(slices)
        slices(i).slice_points_rocs = AddBackSideToProfile(slices(i).slice_points_rocs);
    end

endfunction

function [slices, nbr_samples_per_rev, weldsystem_state_changes, adaptio_state_changes] = ReadWeldControlLog(file_path, nbr_slices_per_weld_length, waitbar_handle, macs_to_rocs_translation, time_range)
    slices = [];
    weldsystem_state_changes = [];
    adaptio_state_changes = [];
    object_radius = 0.720; //m

    nbr_samples_per_rev = nbr_slices_per_weld_length;
    slice_step = 2 * %pi / nbr_slices_per_weld_length; // Use 1.0 instead of 2PI for fractional position
    max_pos_index = nbr_slices_per_weld_length - 1;
    torch_to_laser_fraction = 2*%pi * 0.135 / (2*%pi * object_radius); // TODO: Pass this in.
    start_position = %nan;

    // Buffer for welding params that should be matched to profiles
    // that appear later in the log.
    param_buffer = cell(1,nbr_samples_per_rev);

    // Open and read complete file
    fd = mopen(file_path, "rt");
    try
        file_content = mgetl(fd, -1);
    catch
        messagebox("Failed to read log file.", , "Error", "error", "OK", "modal");
        mclose(fd);
        return;
    end

    mclose(fd);

    // Iterate over all the log entries
    latest_slice_index = %nan;
    latest_weld_index = %nan;
    slice_cnt = 1;
    nbr_rows = size(file_content,"*"); 
    for i = 1:nbr_rows
        waitbar(i/nbr_rows, waitbar_handle);
        row = file_content(i);
        //Only handle rows starting with the beadControl JSON object
        //if strindex(row, "/^{""beadControl/", "r") == 1
        log_item = fromJSON(row);

        [log_time, success] = TryConvertStringToDateTime(log_item.timestamp); 
        if log_time < time_range.start | log_time > time_range.end
            continue;
        end

        // Store state changes
        if isfield(log_item, "annotation") 
            if log_item.annotation == "weld-system-state-change"
                weldsystem_state_changes = [weldsystem_state_changes,,... 
                                            struct("type", log_item.annotation,...
                                                   "timestamp", log_item.timestamp,...
                                                   "ws1_state", log_item.weldSystems(1).state,...
                                                   "ws2_state", log_item.weldSystems(2).state)];
            
            elseif log_item.annotation == "adaptio-state-change"
                adaptio_state_changes = [adaptio_state_changes,...
                                         struct("type", log_item.annotation,...
                                                "timestamp", log_item.timestamp,...
                                                "state", log_item.mode)];
            end

            continue;
        end
     
        if isfield(log_item, "mode") & isfield(log_item, "beadControl") & ~isfield(log_item, "annotation")

            if log_item.mode == "idle" | log_item.beadControl == []
                continue;
            end

            if isnan(start_position)
                start_position = log_item.weldAxis.position;
            end

            // TODO: The following if blocks handle wrap-around for circumferential object
            // this will not work for longitudinal, since there is not wrap-around there and the run on/off should not be part of plotting data.
            // Position on object where this profile comes from
            // Position is relative to where the first profile was taken
            adjusted_profile_position = log_item.weldAxis.position - start_position;
            if log_item.weldAxis.position < start_position
                adjusted_profile_position = 2 * %pi + adjusted_profile_position; // Use 1.0 instead of 2PI for fractional position
            end
            
            // Position on object where these welding parameters and torch pos comes from
            adjusted_weld_position = adjusted_profile_position - torch_to_laser_fraction;
            if adjusted_weld_position < 0
                adjusted_weld_position = 2 * %pi + adjusted_weld_position; // Use 1.0 instead of 2PI for fractional position
            end

            // Weld index is used to store parameters and torch pos
            // Slice index is used to retrieve parameters and torch pos for a profile given by slice_index
            // Both indices refer to the same position/interval on the weld object but at different
            // times/logitems.
            weld_index = floor(adjusted_weld_position / slice_step); // Zero based index
            slice_index = floor(adjusted_profile_position / slice_step); // Zero based index

            // Ignore weld params on run on/off plates
            if (weld_index >= 0 & weld_index <= max_pos_index)

                // Only use the weld params if it is the first slice in a new position interval
                if isnan(latest_weld_index) | weld_index <> latest_weld_index
                    param_buffer{weld_index + 1} = log_item;
                    latest_weld_index  = weld_index;
                end
            end
            
            // Ignore profiles on run on/off plates
            if (slice_index >= 0 & slice_index <= max_pos_index)
                
                // Only use the slice if it is the first slice in a new position interval
                if isnan(latest_slice_index) | slice_index <> latest_slice_index
                    
                    // Check if params for this position interval have been read from log yet
                    params_buffered = param_buffer{slice_index + 1} <> [];

                    // Convert to the format used for the test log
                    log_item.mcsProfile.y = 0.0; // Add y coordinate
                    log_item.mcs.y = 0.0;

                    profile_macs = log_item.mcsProfile;
                    //profile_macs = AddBackSideToProfile(profile_macs);
                    profile_macs = ConvertPointsFromMmToM(profile_macs);
                    profile_rocs = ConvertPointsFromMacsToRocs(profile_macs, macs_to_rocs_translation);
                    abw_macs =  ConvertPointsFromMmToM(log_item.mcs);
                    abw_rocs = ConvertPointsFromMacsToRocs(abw_macs, macs_to_rocs_translation);
                    
                    // Init some default variables
                    torch_pos = struct("x", 0.0,...
                                       "y", 0.0,...
                                       "z", 0.0);
                    current = 0.0;
                    weld_speed = 0.0;

                    if params_buffered
                        torch_pos.x = param_buffer{slice_index + 1}.slides.actual.horizontal; //MACS
                        torch_pos.z = param_buffer{slice_index + 1}.slides.actual.vertical;   //MACS
                        torch_pos   = ConvertPointsFromMmToM(torch_pos);
                        torch_pos   = ConvertPointsFromMacsToRocs(torch_pos, macs_to_rocs_translation);
                        current     = param_buffer{slice_index + 1}.weldSystems(2).current.actual;
                        weld_speed  = param_buffer{slice_index + 1}.weldAxis.velocity.actual / 1000; //mm/s --> m/s
                    end

                    slice_obj = struct("current",            current,...
                                      "slice_points_rocs",   profile_rocs,...
                                      "slice_sample_index",  slice_index,...
                                      "torch_pos_rocs",      torch_pos,...
                                      "weld_speed",          weld_speed,...
                                      "abw_points",          abw_rocs,...
                                      "empty_groove",        %f,...
                                      "time_stamp",          log_item.timestamp);

                    //if log_item.beadControl.layerNo == 1 & log_item.beadControl.beadNo == 1 
                    if ~params_buffered
                        slice_obj.empty_groove = %t;
                    end

                    slices(slice_cnt) = slice_obj;
                    latest_slice_index = slice_index;
                    slice_cnt = slice_cnt + 1;          
                end
            end
        end
    end

    slices = RectifySlices(slices, nbr_samples_per_rev, waitbar_handle);

endfunction


function [slices, nbr_samples_per_rev] = ReadTestLog(file_path, test_case, waitbar_handle)

    fd = mopen(file_path, "rt");
    try
        mgetl(fd, test_case.start_row);
        nbr_rows_in_test_case = -1;
        if ~isinf(test_case.end_row) 
            nbr_rows_in_test_case = test_case.end_row - test_case.start_row;
        end

        file_content = mgetl(fd, nbr_rows_in_test_case);
    catch
        mclose(fd);
        messagebox("Failed to read log file.", , "Error", "error", "OK", "modal");
    end

    mclose(fd);
    // Grep the relevant rows in the file Slice sample index
    [slice_rows, w] = grep(file_content,"first_slice_behind_torch");
    
    // Get the JSON objects
    slices = [];
    nbr_samples_per_rev = 0;
    nbr_slices = length(slice_rows);
    for i = 1:nbr_slices
        waitbar(i/nbr_slices, waitbar_handle);
        json_string = "{";
        row_idx = slice_rows(i) + 1;
        unclosed_brace_cnt = 1;
        while unclosed_brace_cnt <> 0
            row = file_content(row_idx);
            json_string = [json_string; row];
            row_idx = row_idx + 1;
            if grep(row, "{")
                unclosed_brace_cnt = unclosed_brace_cnt + 1;
            end
            if grep(row, "}")
                unclosed_brace_cnt = unclosed_brace_cnt - 1;
            end
        end
        
        //Deserialize
        obj = fromJSON(json_string);
        //slices = [slices,obj];
        obj.empty_groove = %f;
        if obj.current == []
          obj.empty_groove = %t;
        end
        slices(i) = obj;
        nbr_samples_per_rev = max([nbr_samples_per_rev, obj.slice_sample_index + 1]);
        
    end  
endfunction

function [fig] = InitPlotWindow(plot_settings)
    // Init plot window
    handles = [];

    fig = scf();
    fig.figure_size = [626,1000];
    fig.figure_name = msprintf("Adaptivity visualizer (%i)", fig.figure_id);
    clf(fig);
    fig.immediate_drawing = "off";
    fig.color_map = jet(plot_settings.n_colors);
    m = uimenu(fig,'label', 'Adaptivity');
    m2 = uimenu(m,'label', 'Show controls', 'callback', msprintf("CreateTestLogGui(%i)", fig.figure_id));
    delete(fig.children(2));

    deposition_min = plot_settings.current_min / plot_settings.speed_max;
    deposition_max = plot_settings.current_max / plot_settings.speed_min;
    unit_text = "";
    
    for j = 1:3
        subplot(3,1,j)
        ax = gca()
        ax.isoview = "on";
        ax.box = "on";
        ax.axes_reverse(1) = "on";
        ax.font_size = 3;
        ax.title.font_size = 3;
        ax.x_label.text = "ROCS x (m)";
        ax.x_label.font_size = 3;
        ax.y_label.text = "ROCS r (m)";
        ax.y_label.font_size = 3;
        ax.zoom_box = plot_settings.zoom_box;
        
        select j
        case 1
            handles.dep_axes_handle = ax;
            ax.title.text = msprintf("Adaptivity at %.1f°", 0);;
            min_value = deposition_min / 1000;
            max_value = deposition_max / 1000;
            unit_text = "As/mm";
            handles.dep_colorbar_handle = colorbar(min_value, max_value, [1,64]);
            handles.dep_colorbar_handle.title.text = unit_text;
            e = gce();
            e.font_size = 3;
        case 2
            handles.current_axes_handle = ax;
            ax.title.text = msprintf("Current at %.1f°", 0);
            min_value = plot_settings.current_min;
            max_value = plot_settings.current_max;
            unit_text = "A";
            handles.current_colorbar_handle = colorbar(min_value, max_value, [1,64]);
            handles.current_colorbar_handle.title.text = unit_text;
            e = gce();
            e.font_size = 3;
        case 3
            handles.speed_axes_handle = ax;
            ax.title.text = msprintf("Speed at %.1f°", 0);
            min_value = plot_settings.speed_min * 6000;
            max_value = plot_settings.speed_max * 6000;
            unit_text = "cm/min";
            handles.speed_colorbar_handle = colorbar(min_value, max_value, [1,64]);
            handles.speed_colorbar_handle.title.text = unit_text;
            e = gce();
            e.font_size = 3;
        end

    end

    fig.user_data.plot_settings = plot_settings;
    fig.user_data.handles = handles;
    fig.user_data.slices = [];
    fig.user_data.control_win_tag = "";

endfunction

function [] = PlotBeadsAtPosition(position_index, fig)
    
    k = find(list2vec(fig.user_data.slices.slice_sample_index) == position_index);
    slices = fig.user_data.slices(k);

    scf(fig);
    fig.immediate_drawing = "off";
    plot_settings = fig.user_data.plot_settings;
    handles = fig.user_data.handles;
    
    deposition_min = plot_settings.current_min / plot_settings.speed_max;
    deposition_max = plot_settings.current_max / plot_settings.speed_min;
    col_max = plot_settings.n_colors;
    col_min = 1;
    col_black = color("black");
    col_white = color("white");
    ClearPlots(fig);
    //Plot
    for i = [length(slices) : -1 : 1]
        obj = slices(i);

        slice_x = list2vec(obj.slice_points_rocs.x);
        slice_r = sqrt(list2vec(obj.slice_points_rocs.y).^2 + list2vec(obj.slice_points_rocs.z).^2);

        // ================================================
        // Current
        sca(handles.current_axes_handle)
        xfpoly([slice_x; slice_x(1)], [slice_r; slice_r(1)]);
        fill_handle = gce();
        fill_handle.clip_state = "on";
        
        if obj.empty_groove // This is supposed to be the initial empty joint
            fill_handle.background = color("light gray"); 
        else
            plot_value = obj.current;
            min_value = plot_settings.current_min;
            max_value = plot_settings.current_max;
            col_val = ceil(1 + (col_max - 1) * (plot_value - min_value) ./ (max_value - min_value));
            if col_val > col_max then col_val = col_black;end
            if col_val < col_min then col_val = col_white;end
            fill_handle.background = col_val;
        end
        
        if ~obj.empty_groove
            torch_x = obj.torch_pos_rocs.x;
            torch_r = sqrt(obj.torch_pos_rocs.y^2 + obj.torch_pos_rocs.z^2) 
            plot2d(torch_x, torch_r - plot_settings.stickout, -9);
            torch_handle = gce().children(1);
            torch_handle.mark_size_unit = "point";
            torch_handle.mark_size = 4;
            glue([fill_handle, torch_handle.parent]);
        end
        
        // ================================================
        // Speed
        sca(handles.speed_axes_handle);
        xfpoly([slice_x; slice_x(1)], [slice_r; slice_r(1)]);
        fill_handle = gce();
        fill_handle.clip_state = "on";
        
        if obj.empty_groove // This is supposed to be the initial empty joint
            fill_handle.background = color("light gray"); 
        else
            plot_value = obj.weld_speed;
            min_value = plot_settings.speed_min;
            max_value = plot_settings.speed_max;
            col_val = ceil(1 + (col_max - 1) * (plot_value - min_value) ./ (max_value - min_value));
            if col_val > col_max then col_val = col_black;end
            if col_val < col_min then col_val = col_white;end
            fill_handle.background = col_val;
        end
        
        if ~obj.empty_groove
            torch_x = obj.torch_pos_rocs.x;
            torch_r = sqrt(obj.torch_pos_rocs.y^2 + obj.torch_pos_rocs.z^2) 
            plot2d(torch_x, torch_r - plot_settings.stickout, -9)
            torch_handle = gce().children(1);
            torch_handle.mark_size_unit = "point";
            torch_handle.mark_size = 4;
            glue([fill_handle, torch_handle.parent]);
        end
            
        // ================================================
        // Deposition
        sca(handles.dep_axes_handle);
        xfpoly([slice_x; slice_x(1)], [slice_r; slice_r(1)]);
        fill_handle = gce();
        fill_handle.clip_state = "on";
        
        if obj.empty_groove // This is supposed to be the initial empty joint
            fill_handle.background = color("light gray"); 
        else
            plot_value = obj.current / obj.weld_speed;
            min_value = deposition_min;
            max_value = deposition_max;
            col_val = ceil(1 + (col_max - 1) * (plot_value - min_value) ./ (max_value - min_value));
            if col_val > col_max then col_val = col_black;end
            if col_val < col_min then col_val = col_white;end
            fill_handle.background = col_val;
        end
    
        if ~obj.empty_groove
            torch_x = obj.torch_pos_rocs.x;
            torch_r = sqrt(obj.torch_pos_rocs.y^2 + obj.torch_pos_rocs.z^2);
            plot2d(torch_x, torch_r - plot_settings.stickout, -9);
            torch_handle = gce().children(1);
            torch_handle.mark_size_unit = "point";
            torch_handle.mark_size = 4;
            glue([fill_handle, torch_handle.parent]);
        end
        
    end
    
    SetBeadVisibility(fig, length(slices) - 1);
    //SetBeadVisibility(fig, plot_settings.nbr_beads_to_show);
    // Turn on immediate drawing again to show what has been plotted.
    fig.immediate_drawing = "on";

endfunction



function [] = PlotTimeSeriesData(ts_fig, log_data)
    bg_col = addcolor(name2rgb('light green')/255);
    [dt_start, success] = TryConvertStringToDateTime(fromJSON(log_data(1)).timestamp);
    [dt_end, success] = TryConvertStringToDateTime(fromJSON(log_data($)).timestamp);
    current_time_from_start = [];
    current = [];
    ws1_state_changes = [];
    ws2_state_changes = [];
    cnt = 1;
    for i = 1:size(log_data,1)
        log_item = fromJSON(log_data(i));  
        if isfield(log_item, "weldSystems") & log_item.weldSystems <> []
            [dt, success] = TryConvertStringToDateTime(log_item.timestamp);
            time_from_start = (dt - dt_start).duration;
            current_time_from_start(cnt) = time_from_start;
            current(cnt) = log_item.weldSystems(2).current.actual;
            cnt = cnt + 1;
        end
        if isfield(log_item, "annotation")
            if log_item.annotation == "weld-system-state-change"
                new_state_ws2 = log_item.weldSystems(2).state;
                new_state_ws1 = log_item.weldSystems(1).state;
                state_num = MapWeldSystemStateToIndex(new_state_ws2);
                
                if length(ws2_state_changes) > 0
                  prev_state_num = ws2_state_changes($).dst_state;
                else
                  prev_state_num = 0;
                end

                state_struct = struct("src_state", prev_state_num, "dst_state", state_num, "timestamp", log_item.timestamp);
                ws2_state_changes = [ws2_state_changes, state_struct];

            // elseif log_item.annotation == "adaptio-state-change"
            //     adaptio_state_timestamps = strsplit(log_item.timestamp, ["T","+"])(2);
            //     new_state_adaptio = log_item.mode;
            end
        end
    end

    subplot(2,1,1)
    plot2d(current_time_from_start ./ 1000, current);
    ax = gca();
    AddSelectionBox(ax, bg_col);
    ax.data_bounds(1) = 0;
    ax.data_bounds(2) = (dt_end - dt_start).duration ./1000;
    ax.box = "on";
    ax.tight_limits = "on";
    ax.x_label.text = "Time (s)";
    ax.y_label.text = "Current WS2 (A)";
    // for i = 1:length(ax.x_ticks.locations)
    //     log_idx = ax.x_ticks.locations(i);
    //     if log_idx < 1
    //       log_idx = 1; 
    //       ax.x_ticks.locations(i) = log_idx;
    //     end
    //     if log_idx > cnt - 1
    //       log_idx = cnt - 1; 
    //       ax.x_ticks.locations(i) = log_idx;
    //     end
    //     ax.x_ticks.labels(i) = current_timestamps(log_idx);
    // end


    subplot(2,1,2)
    y = [];
    x = [];
    for i = 1:length(ws2_state_changes)
      start_end = [ws2_state_changes(i).src_state;ws2_state_changes(i).dst_state];
      [dt, success] = TryConvertStringToDateTime(ws2_state_changes(i).timestamp);
      time_from_start = (dt - dt_start).duration;
      y = [y, start_end];
      x = [x, [time_from_start;time_from_start]]
    end
    h_arrows = xarrows(x ./ 1000, y);
    h_arrows.clip_state = "on";
    h_arrows.arrow_size = -1.5;

    // State lines
    t = [0,(dt_end-dt_start).duration] ./ 1000;
    plot2d(t, [1,1])
    plot2d(t, [2,2])
    plot2d(t, [3,3])
    plot2d(t, [4,4])

    // Axes pretty
    ax2 = gca();
    AddSelectionBox(ax2, bg_col);
    ax2.data_bounds(1) = 0;
    ax2.data_bounds(2) = (dt_end - dt_start).duration ./ 1000;
    ax2.box = "on";
    ax2.y_ticks = tlist(["ticks","locations","labels", "interpreters"], [1;2;3;4],["ready";"init";"in-weld";"arcing"]);
    ax2.tight_limits = "on";
    ax2.x_label.text = "Time (s)";
    
    ts_fig.user_data.axes_handles = [ax2, ax];
endfunction

function [] = OnUseSubsetPressed(ts_fig_id)
    ts_fig = scf(ts_fig_id);
    first_log = fromJSON(ts_fig.user_data.log_data(1));
    [dt_start, success] = TryConvertStringToDateTime(first_log.timestamp);
    select_handle = ts_fig.user_data.axes_handles(1).user_data.selection_handle;

    selection_start_dur = duration(0, 0, select_handle.data(1,1));
    selection_start_dt = dt_start + selection_start_dur;
    start_string = strsubst(string(selection_start_dt)," ", "T");
    ts_fig.user_data.handles.time_min_edit.string = start_string;

    selection_end_dur = duration(0, 0, select_handle.data(2,1));
    selection_end_dt = dt_start + selection_end_dur;
    end_string = strsubst(string(selection_end_dt)," ", "T");
    ts_fig.user_data.handles.time_max_edit.string = end_string;
    
endfunction

function [] = AddSelectionBox(ax_handle, bg_col)
    sca(ax_handle);
    x_min = ax_handle.data_bounds(1,1);
    y_min = ax_handle.data_bounds(1,2);
    x_max = ax_handle.data_bounds(2,1);
    y_max = ax_handle.data_bounds(2,2);
    h_bounds = xfpoly([x_min,x_max,x_max,x_min],[y_min, y_min,y_max, y_max]);
    h_bounds.foreground = bg_col;
    h_bounds.background = bg_col;
    swap_handles(ax_handle.children($), h_bounds);
    cfg = struct("selection_handle", h_bounds);
    ax_handle.user_data = cfg;
endfunction


function ts_event_handler(fig_no,x,y,ibut)
    
    if ibut == -1 then
        return;
    end

    if ibut <> 0 then return; end

    ts_fig.event_handler_enable = "off";
    fig = scf(fig_no);

    // Determine source axes = currently active axes
    // TODO: Make this independent on number of fig children. To handle new uicontrols
    ax_idx = int(2 * (1 - y / fig.axes_size(2))) + 1;
    src_axes = fig.user_data.axes_handles(ax_idx);
    sca(src_axes);
    all_axes = fig.user_data.axes_handles;

    // Where are the bound in pixel coords
    start_t = src_axes.user_data.selection_handle.data(1,1);
    end_t = src_axes.user_data.selection_handle.data(2,1);
    [start_pix, _, _] = xchange(start_t, 0, "f2i");
    [end_pix, _, _] = xchange(end_t, 0, "f2i");

    // Close enough to hit?
    hit_end = abs(x - end_pix) < 10;
    hit_start = abs(x - start_pix) < 10;

    change_idx = [];
    if hit_end 
        change_idx = [2,3];
        x_min = src_axes.user_data.selection_handle.data(1);
        x_max = src_axes.data_bounds(2);
    elseif hit_start
        change_idx = [1,4];
        x_min = src_axes.data_bounds(1);
        x_max = src_axes.user_data.selection_handle.data(2);
    else
        ts_fig.event_handler_enable = "on";
        return;
    end

    // Vizualize resize hit
    src_axes.user_data.selection_handle.foreground = 5;

    // Where was the click in real coords
    [x_real,y_real,rect] = xchange(x,y,"i2f")
    rep = [x_real, y_real, -1];
    while rep(3) == -1
        rep = xgetmouse([%t,%t]);
        x_new = min(rep(1), x_max);
        x_new = max(x_new, x_min);
        // Change subset selection
        for i = 1:length(all_axes)
            all_axes(i).user_data.selection_handle.data(change_idx) = x_new;
        end
    end

    src_axes.user_data.selection_handle.foreground = src_axes.user_data.selection_handle.background;
    ts_fig.event_handler_enable = "on";
endfunction

function [state_num] = MapWeldSystemStateToIndex(state_string)
    select state_string
    case "ready-to-start"
      state_num = 1;
    case "init"
      state_num = 2;
    case "in-welding-sequence"
      state_num = 3
    case "arcing"
      state_num = 4;
    end
endfunction


function [] = OnShowCurrentChanged(fig_no)
    checkbox_handle = gcbo();
    fig = scf(fig_no);
    if checkbox_handle.value == 0
        fig.user_data.handles.current_axes_handle.visible = "off";
    else
        fig.user_data.handles.current_axes_handle.visible = "on";
    end
endfunction

function [] = OnShowAdaptivityChanged(fig_no)
    checkbox_handle = gcbo();
    fig = scf(fig_no);
    if checkbox_handle.value == 0
        fig.user_data.handles.dep_axes_handle.visible = "off";
    else
        fig.user_data.handles.dep_axes_handle.visible = "on";
    end
endfunction

function [] = OnShowSpeedChanged(fig_no)
    checkbox_handle = gcbo();
    fig = scf(fig_no);
    if checkbox_handle.value == 0
        fig.user_data.handles.speed_axes_handle.visible = "off";
    else
        fig.user_data.handles.speed_axes_handle.visible = "on";
    end
endfunction

function OnExportGraphicsPressed(fig_no, control_win_id)
    pos_step = 22.5;
    export_position = [0 : pos_step : 360 - pos_step]; 
    fig_handle = scf(fig_no);
    control_win = scf(control_win_id);
    h_pos_slider = findobj(control_win, "tag","position_slider");
    h_bead_slider = findobj(control_win, "tag","bead_slider");
    h_bead_label = findobj(control_win, "tag","bead_label");
    h_pos_label = findobj(control_win, "tag","position_label");

    save_dir = uigetdir("","Select output directory");
    if save_dir == ""
        return;
    end

    log_file = fig_handle.user_data.plot_settings.log_file;
    new_dir = fullfile(save_dir, basename(log_file));
    mkdir(new_dir);

    output_file_names = [];
    cnt = 1;
    for position_degrees = export_position
        position_index = int(position_degrees * fig_handle.user_data.plot_settings.nbr_samples_per_rev / 360);
        h_pos_slider.value = position_index;
        
        bead_slider_val = length(find(list2vec(fig_handle.user_data.slices.slice_sample_index) == position_index)) - 1;
        h_label.string = string(bead_slider_val);
        h_bead_slider.Value = bead_slider_val;
        h_bead_slider.max = bead_slider_val;
        fig_handle.user_data.plot_settings.nbr_beads_to_show = bead_slider_val;

        HandlePositionSliderUpdate(fig_handle, h_pos_slider, h_bead_slider, h_pos_label, h_bead_label);
        sleep(500);
        image_file_names(cnt) = fullfile(new_dir, msprintf("position_%i_deg.pdf", position_degrees)); 
        xs2pdf(fig_no, image_file_names(cnt));
        cnt = cnt + 1;
    end

    report_string = BuildLatexReport(image_file_names, basename(log_file) + fileext(log_file));
    tex_report_path = fullfile(new_dir,"report.tex");
    mputl(report_string, tex_report_path);
    host(msprintf("pdflatex -output-directory=%s %s ", new_dir, tex_report_path));

endfunction

function [report_string] = BuildLatexReport(image_file_names, log_file)
    CRLF = char(13) + char(10);
    report_template = strcat(mgetl("report_template.tex",-1), CRLF);

    figure_template = strcat(["\begin{figure}[ht]";...
                              "\centering";...
                              "\includegraphics[width=1.0\textwidth]{{0}}";...
                              "\end{figure}"], CRLF);

    for i = 1:size(image_file_names, 1)
        figure_sections(i) = strsubst(figure_template, "{0}", image_file_names(i));
    end
    
    report_string = strsubst(report_template, "{figures}", strcat(figure_sections, CRLF));
    report_string = strsubst(report_string, "{log_file}", log_file);

endfunction

function [] = OnBeadSliderChanged(fig_no, control_win_id)
    h_slider = gcbo(); // Get callback object
    h_slider.callback_type = -1; // Stop listening to slider changes
    control_win = scf(control_win_id);
    fig = scf(fig_no);
    h_label = findobj(control_win, "tag","bead_label");
    //slider_changing = %f;
    //while slider_changing
      slider_val = h_slider.Value;
      h_label.string = string(slider_val);
      fig.user_data.plot_settings.nbr_beads_to_show = slider_val;
      
      SetBeadVisibility(fig, slider_val);
      //slider_changing = h_slider.value <> slider_val;
    //end
    //Check if slider value has changed during the execution of this callback
    // if h_slider.value <> slider_val
    //     OnBeadSliderChanged(fig_no, control_win_id);
    // end

    h_slider.callback_type = 2; // Start listening to changes again
endfunction

function [] = OnPositionSliderChanged(fig_no, control_win_id, iter)

    h_pos_slider = gcbo(); //findobj(control_win, "tag","position_slider");
    // Stop listening to slider changes to avoid flooding
    // of events from UI. 
    // Reason: Scilab cannot execute this particular callback
    // fast enough --> build up of waiting callbacks --> lag and crash risk.
    h_pos_slider.callback_type = -1;
    //iter = iter + 1;
    control_win = scf(control_win_id);
    fig_handle = scf(fig_no);

    h_bead_slider = findobj(control_win, "tag","bead_slider");
    h_bead_label = findobj(control_win, "tag","bead_label");
    h_pos_label = findobj(control_win, "tag","position_label");

    HandlePositionSliderUpdate(fig_handle, h_pos_slider, h_bead_slider, h_pos_label, h_bead_label);
    
    // Check if pos slider has changed during the callback execution
    // This is done to handle all the missed slider changes during
    // callback execution when listenting is shut off.
    // if position_index <> h_slider.value & iter < 15;
    //     OnPositionSliderChanged(fig_no, control_win_id, iter);
    // end

    h_pos_slider.callback_type = 2; // Start listening to changes again

endfunction

function [] = HandlePositionSliderUpdate(fig_handle, h_pos_slider, h_bead_slider, h_pos_label, h_bead_label)

  slider_changing = %t;
  while slider_changing
      position_index = h_pos_slider.value;
      position_degrees = position_index * 360 / fig_handle.user_data.plot_settings.nbr_samples_per_rev;
      h_pos_label.string = msprintf("%.1f°", position_degrees);
      nbr_beads_at_position = length(find(list2vec(fig_handle.user_data.slices.slice_sample_index) == position_index)) - 1;

      fig_handle.user_data.handles.dep_axes_handle.title.text = msprintf("Adaptivity at %.1f°", position_degrees);
      fig_handle.user_data.handles.current_axes_handle.title.text = msprintf("Current at %.1f°", position_degrees);
      fig_handle.user_data.handles.speed_axes_handle.title.text = msprintf("Speed at %.1f°", position_degrees);

      if nbr_beads_at_position < h_bead_slider.value
          h_bead_slider.value = nbr_beads_at_position;
          h_bead_label.string = string(nbr_beads_at_position);
          fig_handle.user_data.plot_settings.nbr_beads_to_show = nbr_beads_at_position;
      end

      h_bead_slider.max = nbr_beads_at_position

      PlotBeadsAtPosition(position_index, fig_handle);
      slider_changing = h_pos_slider.value <> position_index;
  end

endfunction

function [] = OnSelectFilePressed(fig_no, control_win_id)
    control_win = scf(control_win_id);
    fig_handle = scf(fig_no);  
    file_path = uigetfile(["*.txt"; "*.log"]);
    test_cases = [];
    log_type = "unknown";

    ClearPlots(fig_handle);
    DisableControls(control_win);

    if file_path <> ""
        h_label = findobj(control_win, "tag", "file_path_edit");
        h_label.string = file_path;
        h_button = findobj(control_win, "tag", "load_button");
        h_button.enable = "off";
        h_test_combo = findobj(control_win, "tag", "test_case_combobox");
        h_log_label = findobj(control_win, "tag","log_type_label");
        h_time_min_edit = findobj(control_win, "tag","time_min_edit");
        h_time_max_edit = findobj(control_win, "tag","time_max_edit");
  
        p_handle = progressionbar("Checking file for test cases..");
        try
            test_cases = FindTestCasesInFile(file_path);
        catch
            close(p_handle);
            messagebox("Failed to parse log file", "Error", "error", "OK", "modal");
            return;
        end
        close(p_handle);
    
        items = "";
        for i = 1:length(test_cases)
            items = items + "|" + test_cases(i).test_name;
        end
        h_test_combo.string = items;
        fig_handle.user_data.plot_settings.test_cases = test_cases;

        // Test cases are found in file, it is assumed to be a test log
        // otherwise weld control log
        if size(test_cases,"*") == 0
            log_type = "weld control log";
            h_test_combo.enable = "off";
            h_test_combo.value = 0;
        else
            log_type = "block test log";
            h_test_combo.enable = "on";
            h_test_combo.value = 1;
        end

        // Load all the raw logs and store for fast access
        if log_type == "weld control log"
            try
                log_data = GetWeldControlLog(file_path);
                [datetime_start, datetime_end] = GetStartAndEndTimes(log_data);
            catch
                // Do nothing
            end
        
            fig_handle.user_data.log_data = log_data;

            if datetime_start <> "" & datetime_end <> ""
                h_time_min_edit.string = datetime_start;
                h_time_max_edit.string = datetime_end;
            end
        end


        h_button.enable = "on";
    end

    fig_handle.user_data.plot_settings.log_type = log_type;
    h_log_label.string = msprintf("Current log type: %s", log_type);

    EnableControls(control_win);

endfunction

function [log_data] = GetWeldControlLog(file_path)
    log_data = [];
    fd = mopen(file_path, "rt");
    try
        log_data = mgetl(fd, -1);
    catch
        mclose(fd);
        error("Failed to read log file.");
    end

    mclose(fd);
endfunction

function [datetime_start, datetime_end] = GetStartAndEndTimes(file_content)

    log_item = fromJSON(file_content(1));
    datetime_start = log_item.timestamp;
    log_item = fromJSON(file_content($));
    datetime_end = log_item.timestamp;

endfunction

function [num_value, is_valid] = ValidateNumericValue(num_string, expected_dim)

    num_value = [];
    try
      num_value = evstr(num_string);
      actual_dim = size(num_value);
      is_valid = and(actual_dim == expected_dim);
    catch
        is_valid = %f;
        return;
    end

endfunction

function [dt, success] = TryConvertStringToDateTime(timestamp_string) 
    success = %f;
    dt = [];
    parts = strsplit(timestamp_string, ["-","T",":",".","+"]);
    n_parts = size(parts, 1);
    
    // Check nbr of parts in string, must be 7 or 9 (the latter including the time zone data)
    if n_parts < 7
      return;
    end

    //Check that string are numbers of right length
    if length(parts(1)) <> 4 | ~and(isdigit(parts(1)))// year
        return;
    end
    if length(parts(2)) <> 2 | ~and(isdigit(parts(2)))// month
        return;
    end
    if length(parts(3)) <> 2 | ~and(isdigit(parts(3))) // day
        return;
    end
    if length(parts(4)) <> 2 | ~and(isdigit(parts(4))) // hour
        return;
    end
    if length(parts(5)) <> 2 | ~and(isdigit(parts(5))) // minute
        return;
    end
    if length(parts(6)) <> 2 | ~and(isdigit(parts(6))) // sec
        return;
    end
    if length(parts(7)) <> 3 | ~and(isdigit(parts(7))) // millisec
        return;
    end

    datetime_string = strcat(parts(1:3),"-") + " " + strcat(parts(4:6),":") + "." + parts(7);
    dt = datetime(datetime_string);
    success = %t;

endfunction

function [success] = GetAndValidateUiSettings(fig_handle, control_win)
    success = %f;

    // Log file
    h = findobj(control_win, "tag", "file_path_edit");
    file_path = h.string;
    if ~isfile(file_path)
      messagebox("File does not exist.", "Error", "error", "OK", "modal");
      return;
    end
    fig_handle.user_data.plot_settings.log_file = file_path;

    // MACS to ROCS
    h = findobj(control_win, "tag", "masc_to_rocs_translation_edit");
    [num_value, is_valid] = ValidateNumericValue(h.string, [3,1]);
    if ~is_valid
        messagebox("MACS to ROCS translation has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.macs_to_rocs_translation = num_value;

    // Nbr of samples
    h = findobj(control_win, "tag", "nbr_samples_edit");
    [num_value, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Nbr of sammples has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.nbr_samples_per_rev = num_value;    

    // Stickout
    h = findobj(control_win, "tag", "stickout_edit");
    [num_value, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Stickout has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.stickout = num_value;    

    // Current range
    h = findobj(control_win, "tag", "current_min_edit");
    [current_min, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Min of current range has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    h = findobj(control_win, "tag", "current_max_edit");
    [current_max, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Max of current range has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    if current_max <= current_min
        messagebox("In current range, max is less than min.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.current_max = current_max;  
    fig_handle.user_data.plot_settings.current_min = current_min;

    // Speed range
    h = findobj(control_win, "tag", "speed_min_edit");
    [speed_min, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Min of speed range has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    h = findobj(control_win, "tag", "speed_max_edit");
    [speed_max, is_valid] = ValidateNumericValue(h.string, [1,1]);
    if ~is_valid
        messagebox("Max of speed range has invalid format.", "Error", "error", "OK", "modal");
        return;
    end
    if speed_max <= speed_min
        messagebox("In speed range, max is less than min.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.speed_max = speed_max;  
    fig_handle.user_data.plot_settings.speed_min = speed_min;

    // Time limits
    h = findobj(control_win, "tag", "time_min_edit");
    [dt_start, success] = TryConvertStringToDateTime(h.string);
    if ~success
        messagebox("Start time is not a valid datetime.", "Error", "error", "OK", "modal");
        return;
    end
    h = findobj(control_win, "tag", "time_max_edit");
    [dt_end, success] = TryConvertStringToDateTime(h.string);
    if ~success
        messagebox("End time is not a valid datetime.", "Error", "error", "OK", "modal");
        return;
    end
    if (dt_start > dt_end)
        messagebox("In time range, end is before than start.", "Error", "error", "OK", "modal");
        return;
    end
    fig_handle.user_data.plot_settings.time_max = dt_end;  
    fig_handle.user_data.plot_settings.time_min = dt_start;

    // TODO: Add validation of the other inputs as well

    success = %t;
endfunction

function [] = UpdateColorBars(fig_handle)

  handles = fig_handle.user_data.handles;

  // Current color bar
  current_min = fig_handle.user_data.plot_settings.current_min;
  current_max = fig_handle.user_data.plot_settings.current_max;
  speed_min = fig_handle.user_data.plot_settings.speed_min;
  speed_max = fig_handle.user_data.plot_settings.speed_max;
  deposition_min = current_min / speed_max;
  deposition_max = current_max / speed_min;

  n_labels = length(handles.current_colorbar_handle.y_ticks.locations);
  handles.current_colorbar_handle.y_ticks = tlist(["ticks","locations","lables","interpreters"],...
                                              handles.current_colorbar_handle.y_ticks.locations,...
                                              msprintf("%i\n",linspace(current_min, current_max, n_labels)'));

  n_labels = length(handles.speed_colorbar_handle.y_ticks.locations);
  handles.speed_colorbar_handle.y_ticks = tlist(["ticks","locations","lables","interpreters"],...
                                              handles.speed_colorbar_handle.y_ticks.locations,...
                                              msprintf("%.1f\n",linspace(speed_min * 6000, speed_max * 6000, n_labels)'));

  n_labels = length(handles.dep_colorbar_handle.y_ticks.locations);
  handles.dep_colorbar_handle.y_ticks = tlist(["ticks","locations","lables","interpreters"],...
                                              handles.dep_colorbar_handle.y_ticks.locations,...
                                              msprintf("%i\n",linspace(deposition_min, deposition_max, n_labels)'));

endfunction

function [] = OnViewTimeSeriesPressed(top_fig_id, control_win_id)

    main_win = scf(top_fig_id);
    control_win = scf(control_win_id);
    h_time_min_edit = findobj(control_win, "tag","time_min_edit");
    h_time_max_edit = findobj(control_win, "tag","time_max_edit");

    ts_fig_handle = CreateTimeSeriesGui(h_time_min_edit, h_time_max_edit, main_win.user_data.log_data);
    
    //Store the ts handle

    //

endfunction

function [] = OnLoadLogFilePressed(fig_no, control_win_id)

    control_win = scf(control_win_id);
    fig_handle = scf(fig_no);
    //h_label = findobj(control_win, "tag", "file_path_edit");
    h_combobox = findobj(control_win, "tag", "test_case_combobox");
    //file_path = h_label.string;
    if ~GetAndValidateUiSettings(fig_handle, control_win)
        return;
    end

    ClearPlots(fig_handle);
    UpdateColorBars(fig_handle);
    DisableControls(control_win);

    is_test_log = size(fig_handle.user_data.plot_settings.test_cases,"*") <> 0; // Potential test cases are found earlier when user selecting the file.
    file_path = fig_handle.user_data.plot_settings.log_file;
    macs_to_rocs_translation = fig_handle.user_data.plot_settings.macs_to_rocs_translation; // Needed for weldcontrollog mode
    nbr_samples = fig_handle.user_data.plot_settings.nbr_samples_per_rev;
    time_range = struct("start",[], "end", []);
    time_range.start = fig_handle.user_data.plot_settings.time_min;
    time_range.end = fig_handle.user_data.plot_settings.time_max;

    // Read new data
    p_handle = waitbar("Parsing log file..");
    try
        if is_test_log
            test_case_index = h_combobox.value;
            test_case = fig_handle.user_data.plot_settings.test_cases(test_case_index);
            [slices, nbr_samples_per_rev] = ReadTestLog(file_path, test_case, p_handle);
            state_changes = [];
        else
            [slices, nbr_samples_per_rev, weldsystem_state_changes, adaptio_state_changes] = ReadWeldControlLog(file_path, nbr_samples, p_handle, macs_to_rocs_translation, time_range);
        end
    catch
        close(p_handle);
        [err_msg, n, line, func] = lasterror();
        messagebox(msprintf("Error: %s\nLine: %i\nFunction: %s", err_msg, line, func), "Error", "error", "OK", "modal");
        EnableControls(control_win);
        return;
    end
    close(p_handle);

    nbr_beads_at_position = length(find(list2vec(slices.slice_sample_index) == 0)) - 1;
    fig_handle.user_data.plot_settings.nbr_samples_per_rev = nbr_samples_per_rev;
    fig_handle.user_data.plot_settings.nbr_beads_to_show = nbr_beads_at_position;
    fig_handle.user_data.slices = slices;
    fig_handle.user_data.weldsystem_state_changes = weldsystem_state_changes;
    fig_handle.user_data.adaptio_state_changes = adaptio_state_changes;

    // Reset position and bead sliders
    h_slider = findobj(control_win, "tag","bead_slider");
    h_label = findobj(control_win, "tag","bead_label");
    h_slider.Value = 0;
    h_slider.max = nbr_beads_at_position
    h_slider.Value = nbr_beads_at_position;
    h_label.string = string(nbr_beads_at_position);

    h_slider = findobj(control_win, "tag","position_slider");
    h_label = findobj(control_win, "tag","position_label");
    h_slider.Value = 0;
    h_slider.max = nbr_samples_per_rev - 1;
    h_label.string = "0°";

    // Replot
    PlotBeadsAtPosition(0, fig_handle);
    EnableControls(control_win);
    SetZoomBox(slices, fig_handle.user_data.handles);    
    
    fig_handle.user_data.handles.dep_axes_handle.title.text = msprintf("Adaptivity at %.1f°", 0);
    fig_handle.user_data.handles.current_axes_handle.title.text = msprintf("Current at %.1f°", 0);
    fig_handle.user_data.handles.speed_axes_handle.title.text = msprintf("Speed at %.1f°", 0);

endfunction

function [] = SetZoomBox(slices, axes_handles)

  x_min = %inf;
  x_max = -%inf;
  z_min = %inf;
  z_max = -%inf;
  for i = 1:length(slices)
      x_min = min(x_min, slices(i).abw_points(7).x);
      x_max = max(x_max, slices(i).abw_points(1).x);

      z_min = min(z_min, sqrt(slices(i).abw_points(2).z^2 + slices(i).abw_points(2).y^2));
      z_min = min(z_min, sqrt(slices(i).abw_points(3).z^2 + slices(i).abw_points(3).y^2));
      z_min = min(z_min, sqrt(slices(i).abw_points(4).z^2 + slices(i).abw_points(4).y^2));
      z_min = min(z_min, sqrt(slices(i).abw_points(5).z^2 + slices(i).abw_points(5).y^2));
      z_min = min(z_min, sqrt(slices(i).abw_points(6).z^2 + slices(i).abw_points(6).y^2));
      
      z_max = max(z_max, sqrt(slices(i).abw_points(1).z^2 + slices(i).abw_points(1).y^2));
      z_max = max(z_max, sqrt(slices(i).abw_points(7).z^2 + slices(i).abw_points(7).y^2));
  end

  x_range = x_max - x_min;
  z_range = z_max - z_min;
  x_margin = x_range * 0.1;
  z_margin = z_range * 0.1;
  zb =  [x_min - x_margin, z_min - z_margin,x_max + x_margin, z_max + z_margin, -1, 1];

  axes_handles.dep_axes_handle.zoom_box = zb;
  axes_handles.current_axes_handle.zoom_box = zb;
  axes_handles.speed_axes_handle.zoom_box = zb;

endfunction

function [] = EnableControls(control_win_handle)
    
    for i = 1:length(control_win_handle.children)
        if control_win_handle.children(i).type == "uicontrol"
            control_win_handle.children(i).enable = "on";
        end
    end

endfunction

function [] = DisableControls(control_win_handle)
    
    for i = 1:length(control_win_handle.children)
        if control_win_handle.children(i).type == "uicontrol"
            control_win_handle.children(i).enable = "off";
        end
    end

endfunction

function [] = ClearPlots(fig)
    //Erase previous plots
    handles = fig.user_data.handles;
    delete(handles.current_axes_handle.children);
    delete(handles.speed_axes_handle.children);
    delete(handles.dep_axes_handle.children);

endfunction

function [] = SetBeadVisibility(fig, nbr_beads_to_show)

    // Weld speed axes
    fig.user_data.handles.speed_axes_handle.children(1:nbr_beads_to_show + 1).visible = "on";
    fig.user_data.handles.speed_axes_handle.children(nbr_beads_to_show + 2 : $).visible = "off";
    // Weld current axes
    fig.user_data.handles.current_axes_handle.children(1:nbr_beads_to_show + 1).visible = "on";
    fig.user_data.handles.current_axes_handle.children(nbr_beads_to_show + 2 : $).visible = "off";
    // Adaptivity axes
    fig.user_data.handles.dep_axes_handle.children(1:nbr_beads_to_show + 1).visible = "on";
    fig.user_data.handles.dep_axes_handle.children(nbr_beads_to_show + 2 : $).visible = "off";
endfunction
