## globals

function __init__()

    global is_running = true #should probably use g_main_loop_is_running or something of the sort

    global const default_settings = init_opt()

    global main_window = MainWindow()

    ## Console

    console_mng = ConsoleManager(main_window)
    init!(console_mng)

    ## Editor

    editor = Editor(main_window)

    search_window = SearchWindow(editor)
    init!(search_window)
    visible(search_window,false)

    init!(editor,search_window)

    global project = Project(main_window)

    pathCBox = PathComboBox(main_window)
    statusBar = @GtkStatusbar()

    init!(main_window,editor,console_mng,pathCBox,statusBar,project)

    load(project)
    cd(project.path)
    load_tabs(editor,project)

    menubar = MainMenu(main_window)

    global sidepanel_ntbook = @GtkNotebook()

    ## Main layout
    global mainPan = @GtkPaned(:h)
    rightPan = @GtkPaned(:v)

    main_window |>
        ((mainVbox = @GtkBox(:v)) |>
            menubar |>
            (topBarBox = @GtkBox(:h) |>
                (sidePanelButton = @GtkButton("F1")) |>
                 pathCBox   |>
                (editorButton = @GtkButton("F2"))
            ) |>
            (sidePan = @GtkPaned(:h)) |>
            statusBar
        )

    mainPan |>
        (rightPan |>
            #(canvas = @GtkCanvas())  |>
            (fig_ntbook)  |>
            console_mng
        ) |>
        ((editorVBox = @GtkBox(:v)) |>
            ((editorBox = @GtkBox(:h)) |>
                editor |>
                editor.sourcemap
            ) |>
            search_window
        )

    sidePan |>
        sidepanel_ntbook |>
        mainPan

    # Console

    console = first_console(main_window)
    #add_console()
    for i=1:length(free_workers(console_mng))
        add_console(main_window)
    end

    setproperty!(statusBar,:margin,2)
    GtkExtensions.text(statusBar,"Julia $VERSION")
    Gtk.G_.position(sidePan,160)

    setproperty!(editor,:vexpand,true)
    setproperty!(editorBox,:expand,editor,true)
    setproperty!(mainPan,:margin,0)
    Gtk.G_.position(mainPan,600)
    Gtk.G_.position(rightPan,450)
    #-

    setproperty!(topBarBox,:hexpand,true)

    ################
    # Side Panels

    #form_builder = Gtk.GtkBuilderLeaf(filename=joinpath(HOMEDIR,"forms/forms.glade"))
    #filespanel = FilesPanel()
    #update!(filespanel)
    #add_side_panel(filespanel,"Files")

    #=#FIXME I should stop all tasks when exiting
    #this can make it crash if it runs while sorting
    @schedule begin
        while(false)
            sleep(1.0)
            update!(filespanel)
        end
    end=#

    workspacepanel = WorkspacePanel()
    update!(workspacepanel)
    add_side_panel(workspacepanel,"W")

    ################
    ## Plots

    sleep(0.5)
    #figure()
    drawnow() = sleep(0.001)

    init!(pathCBox)#need on_path_change to be defined

    signal_connect(sidePanelButton_clicked_cb, sidePanelButton, "clicked", Void, (), false)
    signal_connect(editorButtonclicked_cb, editorButton, "clicked", Void, (), false)

    showall(main_window)
    visible(search_window,false)
    visible(sidepanel_ntbook,false)
    GtkSourceWidget.SOURCE_MAP && visible(editor.sourcemap,opt("Editor","show_source_map"))

    #

    sleep(0.5)

    if REDIRECT_STDOUT

        global stdout = STDOUT
        global stderr = STDERR

        read_stdout, wr = redirect_stdout()
        #read_stderr, wre = redirect_stderr()

        function watch_stdout()
            @schedule watch_stream(read_stdout,console)
        end
        function watch_stderr()
            @schedule watch_stream(read_stderr,console)
        end

        global watch_stdout_task = watch_stdout()
        #global watch_stderr_task = watch_stderr()

        init_stdout!(main_window.console_manager,watch_stdout_task,stdout,stderr)

        g_timeout_add(100,print_to_console,console)
    end

end
