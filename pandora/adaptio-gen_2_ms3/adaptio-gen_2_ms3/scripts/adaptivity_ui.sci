function [ts_fig] = CreateTimeSeriesGui(time_min_edit, time_max_edit, log_data)

    ts_fig = scf(max(winsid()) + 1);
    ts_fig.figure_size = [1377, 700];
    ts_fig.background = color(200,200,200);
    ts_fig.user_data.handles.time_min_edit = time_min_edit;
    ts_fig.user_data.handles.time_max_edit = time_max_edit;
    ts_fig.user_data.log_data = log_data;
    
    
    PlotTimeSeriesData(ts_fig, log_data)
    
    // TODO: Add layout and additonal uicontrols here.

    uicontrol(ts_fig,..
          "style", "pushbutton",..
          "position", [10,10,80,30],..
          "string", "Select",...
          "enable", "on",...
          "tag", "use_subset_button",...
          "callback", msprintf("OnUseSubsetPressed(%i)", ts_fig.figure_id));

      
    ts_fig.event_handler = "ts_event_handler";
    ts_fig.event_handler_enable = "on";

    
endfunction


function [] = CreateTestLogGui(fig_no)
    
    plot_fig = scf(fig_no);

    control_fig = [];
    // Try get control window if it has been tagged before
    if plot_fig.user_data.control_win_tag <> ""
      control_fig = findobj("tag", plot_fig.user_data.control_win_tag);
    end

    if control_fig == []
        // Existing window not found, create new
        control_fig = createWindow();
        control_fig.figure_name = "Plot control for window " + string(fig_no);
        control_fig.background = color(230,230,230);
        control_fig.figure_size = [550,880];
        control_fig.closerequestfcn = "gcbo().visible = ""off"";";
        //fig.resize = "off"; //Does not seem to work on linux and fucks up figure_size

        os_name = getos();
        if os_name == "Linux"
            [status, uuid, stderr]=host("uuidgen"); //Only works on windows if Win SDK is on path.
        elseif os_name == "Windows"
            [status, uuid, stderr]=host("powershell -Command ""[guid]::NewGuid().ToString()"""); //Using powershell
        end

        if status <> 0
            uuid = string(grand(1,1,'uin',1,1e6)); //Fallback if real UUID could not be generated
        end
        control_fig.tag = uuid;
        plot_fig.user_data.control_win_tag = uuid;
    else
        // Existing window found, raise it.
        control_fig.visible = "on";
        //TODO: This does apparently not work on linux or WSL
        show_window(control_fig);
        return;
    end

    if plot_fig.user_data.quit_on_close
        plot_fig.closerequestfcn = msprintf("close(%i);close(%i);quit()", control_fig.figure_id, fig_no);
    else
        plot_fig.closerequestfcn = msprintf("close(%i);close(%i)", control_fig.figure_id, fig_no);
    end

    nbr_beads = 1;
    plot_settings = plot_fig.user_data.plot_settings;

    enable_controls = "off";
    if plot_fig.user_data.slices <> []
        enable_controls = "on";
    end

    // UI controls
    // c = createConstraints("gridbag",[1, 1, 1, 1], [1, 1], "both", "center", [0, 0], [200, 50]);
    // frame = uicontrol(f , ...
    // "style"               , "frame"                     , ...
    // "backgroundcolor"     , [1 0 0]                     , ...
    // "constraints"         , c,...
    // "layout",               "gridbag",...
    // "scrollable", "on");

    //InitTestLogControlFrame(frame);

    y = 10;
    h = 25;
    w = 300;
    m = 5;
    uicontrol(control_fig,..
          "style", "pushbutton",..
          "position", [10,y,200,h],..
          "string", "Export",...
          "callback", msprintf("OnExportGraphicsPressed(%i, %i)", fig_no, control_fig.figure_id));

    y = y + h + m;       
    uicontrol(control_fig,..
              "style", "checkbox",..
              "position", [10,y,200,h],..
              "string", "Show speed",..
              "value", 1,...
              "callback", msprintf("OnShowSpeedChanged(%i)", fig_no),...
              "enable", enable_controls,..
              "BackgroundColor", [1,1,1]*0.9);       
              
    y = y + h + m;          
    uicontrol(control_fig,..
              "style", "checkbox",..
              "position", [10,y,200,h],..
              "string", "Show current",..
              "value", 1, ...
              "callback", msprintf("OnShowCurrentChanged(%i)", fig_no),...
              "enable", enable_controls,...
              "BackgroundColor", [1,1,1]*0.9);       
    y = y + h + m;  
    uicontrol(control_fig,..
              "style", "checkbox",..
              "position", [10,y,200,h],..
              "string", "Show adaptivity",..
              "value", 1,...
              "callback", msprintf("OnShowAdaptivityChanged(%i)",fig_no),...
              "enable", enable_controls,...
              "BackgroundColor", [1,1,1]*0.9);       
    y = y + h + m;                          
    uicontrol(control_fig,..
              "style", "slider",..
              "value", nbr_beads,..
              "Min", 0,...
              "Max",nbr_beads,...
              "position", [10,y,w,h],...
              "SliderStep", [1,1],..
              "SnapToTicks", "on",...
              "callback", msprintf("OnBeadSliderChanged(%i,%i)", fig_no, control_fig.figure_id),...
              "enable", enable_controls,...
              "tag","bead_slider",..
              "BackgroundColor", [1,1,1]*0.9);
              
    uicontrol(control_fig,..
              "style", "text",..
              "position", [w + 10,y,40,h],..
              "string", string(nbr_beads),...
              "tag","bead_label",..
              "BackgroundColor", [1,1,1]*0.9);

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Bead number",..
              "BackgroundColor", [1,1,1]*0.9);
    
    y = y + h + m;          
    uicontrol(control_fig,..
              "style", "slider",..
              "value", 0,..
              "Min", 0,...
              "Max", plot_settings.nbr_samples_per_rev - 1,...
              "position", [10,y,w,h],...
              "SliderStep", [1,1],..
              "SnapToTicks", "on",...
              "callback", msprintf("OnPositionSliderChanged(%i,%i,%i)", fig_no, control_fig.figure_id, 0),...
              "tag","position_slider",..
              "enable", enable_controls,...
              "BackgroundColor", [1,1,1]*0.9);
              
    uicontrol(control_fig,..
              "style", "text",..
              "position", [w + 10,y,40,h],..
              "string", "0°",...
              "tag","position_label",..
              "BackgroundColor", [1,1,1]*0.9);

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Weld position",..
              "BackgroundColor", [1,1,1]*0.9);              

    //Load button
    y = y + h + 2*m;
    uicontrol(control_fig,..
              "style", "pushbutton",..
              "position", [10,y,w,40],..
              "string", "Load",...
              "enable", enable_controls,...
              "tag", "load_button",...
              "callback", msprintf("OnLoadLogFilePressed(%i, %i)", fig_no, control_fig.figure_id));      
    
    // Time interval
    y = y + 40 + 2*m;          
    w2 = (w - m) / 2
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w2,h],..
              "string", "2026-02-17T8:26:54.000",..
              "BackgroundColor", [1,1,1],...
              "tag", "time_min_edit");
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10+w2+m,y,w2,h],..
              "string", "2026-02-17T10:26:54.383",..
              "BackgroundColor", [1,1,1],...
              "tag", "time_max_edit");

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Time interval to load (yyyy-MM-ddThh:mm:ss.xxx)",..
              "BackgroundColor", [1,1,1]*0.9);     

    // Subset/timeseries button
    y = y + h + 2*m;
    uicontrol(control_fig,..
              "style", "pushbutton",..
              "position", [10,y,w,40],..
              "string", "View time series",...
              "enable", enable_controls,...
              "tag", "load_button",...
              "callback", msprintf("OnViewTimeSeriesPressed(%i, %i)", fig_no, control_fig.figure_id));     

    //Test case selection
    y = y + 40 + 2*m;
    uicontrol(control_fig,..
              "style", "popupmenu",..
              "position", [10,y,w,h],..
              "string", "",..
              "BackgroundColor", [1,1,1],...
              "tag", "test_case_combobox");     

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Test case",..
              "BackgroundColor", [1,1,1]*0.9);  
         

    // Visualization settings
    //Macs to rocs
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w,h],..
              "string", sci2exp(plot_settings.macs_to_rocs_translation),..
              "BackgroundColor", [1,1,1],...
              "tag", "masc_to_rocs_translation_edit");

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "MACS to ROCS translation (m)",..
              "BackgroundColor", [1,1,1]*0.9);   
    
    // Number of samples
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w,h],..
              "string", sci2exp(plot_settings.nbr_samples_per_rev),..
              "BackgroundColor", [1,1,1],...
              "tag", "nbr_samples_edit");

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Number of slices",..
              "BackgroundColor", [1,1,1]*0.9);   

    // Stickout
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w,h],..
              "string", sci2exp(plot_settings.stickout),..
              "BackgroundColor", [1,1,1],...
              "tag", "stickout_edit");

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Stickout (m)",..
              "BackgroundColor", [1,1,1]*0.9);   

    // Speed range
    y = y + h + m;
    w2 = (w - m) / 2
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w2,h],..
              "string", sci2exp(plot_settings.speed_min),..
              "BackgroundColor", [1,1,1],...
              "tag", "speed_min_edit");
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10+w2+m,y,w2,h],..
              "string", sci2exp(plot_settings.speed_max),..
              "BackgroundColor", [1,1,1],...
              "tag", "speed_max_edit");
    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Weld speed range (m/s)",..
              "BackgroundColor", [1,1,1]*0.9);   
    
    // Current range
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w2,h],..
              "string", sci2exp(plot_settings.current_min),..
              "BackgroundColor", [1,1,1],...
              "tag", "current_min_edit");
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10+w2+m,y,w2,h],..
              "string", sci2exp(plot_settings.current_max),..
              "BackgroundColor", [1,1,1],...
              "tag", "current_max_edit");
    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Current range - WS2 (A)",..
              "BackgroundColor", [1,1,1]*0.9);   

    // Log type info
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Log type unknown",..
              "BackgroundColor", [1,1,1]*0.9,...
              "ForegroundColor", [0,0,1],...
              "tag", "log_type_label");

    // Log file
    y = y + h + m;
    uicontrol(control_fig,..
              "style", "edit",..
              "position", [10,y,w,h],..
              "string", plot_settings.log_file,..
              "BackgroundColor", [1,1,1],...
              "tag", "file_path_edit");

    uicontrol(control_fig,..
              "style", "pushbutton",..
              "position", [20 + w,y,90,h],..
              "string", "Browse",...
              "callback", msprintf("OnSelectFilePressed(%i, %i)", fig_no, control_fig.figure_id));

    y = y + h;
    uicontrol(control_fig,..
              "style", "text",..
              "position", [10,y,w,h],..
              "string", "Log file",..
              "BackgroundColor", [1,1,1]*0.9);         

endfunction
