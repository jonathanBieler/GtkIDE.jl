## globals

function init_console!(v, b, main_window)

    set_gtk_property!(b, :style_scheme, main_window.style_and_language_manager.main_style)
    
    highlight_matching_brackets(b, true)
    
    show_line_numbers!(v, false)
    auto_indent!(v, true)
    highlight_current_line!(v, true)
    set_gtk_property!(v, :wrap_mode, 1)
    #set_gtk_property!(v, :expand, true)

    set_gtk_property!(v, :tab_width, 4)
    set_gtk_property!(v, :insert_spaces_instead_of_tabs, true)

    set_gtk_property!(v, :margin_bottom, 10)

    style_css(v, style_provider(main_window))

end

function run()#__init__()

    global is_running = true #should probably use g_main_loop_is_running or something of the sort
    global default_settings = init_opt()
    global main_window = MainWindow()

    ## Console

    console_mng = ConsoleManager(main_window, GtkIDE)
    GtkREPL.init!(console_mng)
    init_console_commands()#insert console commands into GtkREPL

    ## Editor

    editor = Editor(main_window)

    search_window = SearchWindow(editor)
    init!(search_window)
    visible(search_window, false)

    init!(editor, search_window)

    upgrade_project()

    global project = Project(main_window, "default")

    pathCBox = PathComboBox(main_window)
    statusBar = GtkStatusbar()

    menubar = MainMenu(main_window)

    global sidepanel_ntbook = GtkNotebook()

    init!(main_window, editor, console_mng, pathCBox, statusBar, project, menubar, sidepanel_ntbook)
    GtkREPL.set_main_window(main_window) 

    load(project)
    cd(project.path)
    load_tabs(editor, project)

    ## Ploting window

    global fig_ntbook = GtkNotebook()
    global _display = Immerse._display

    #FIXME need init!
    signal_connect(fig_ntbook_key_press_cb, fig_ntbook, "key-press-event", Cint, (Ptr{Gtk.GdkEvent}, ), false)
    signal_connect(fig_ntbook_switch_page_cb, fig_ntbook, "switch-page", Nothing, (Ptr{Gtk.GtkWidget}, Int32), false)

    ## completion window

    global completion_window = CompletionWindow(main_window)
    visible(completion_window, false)

    ## Main layout
    global mainPan = GtkPaned(:h)
    rightPan = GtkPaned(:v)

    main_window |>
        ((mainVbox = GtkBox(:v)) |>
            menubar |>
            (topBarBox = GtkBox(:h) |>
                (sidePanelButton = GtkButton("F1")) |>
                 pathCBox   |>
                (editorButton = GtkButton("F2"))
            ) |>
            (global sidePan = GtkPaned(:h)) |>
            statusBar
        )

    mainPan |>
        (rightPan |>
            #(canvas = GtkCanvas())  |>
            (fig_ntbook)  |>
            console_mng
        ) |>
        ((editorVBox = GtkBox(:v)) |>
            ((editorBox = GtkBox(:h)) |>
                editor |>
                editor.sourcemap
            ) |>
            search_window
        )

    sidePan |>
        sidepanel_ntbook |>
        mainPan

    # Console


    lang = main_window.style_and_language_manager.languageDefinitions[".jl"]
    console = Console{GtkSourceView, GtkSourceBuffer}(
        1, main_window, TCPSocket(), (v, b)->init_console!(v, b, main_window), (lang, )
    )
    GtkREPL.init!(console)

    @assert length(console_mng) == 1

    set_gtk_property!(statusBar, :margin, 2)
    push!(statusBar, "main", "Julia $VERSION")
    Gtk.G_.position(sidePan, 160)

    set_gtk_property!(editor, :vexpand, true)
    set_gtk_property!(editorBox, :expand, editor, true)
    set_gtk_property!(mainPan, :margin, 0)
    Gtk.G_.position(mainPan, 600)
    Gtk.G_.position(rightPan, 450)
    #-

    ## set some style

    nbtbookcss =
    "* tab {
        padding:0px;
        padding-left:6px;
        padding-right:1px;
        margin:0px;
        font-size:$(main_window.style_and_language_manager.fontsize-1)px;
    }"
    style_css(main_window.editor, nbtbookcss)
    style_css(main_window.console_manager, nbtbookcss)
    style_css(fig_ntbook, nbtbookcss)
    style_css(sidepanel_ntbook, nbtbookcss)

    set_gtk_property!(topBarBox, :hexpand, true)

    ################
    # Side Panels

    global filespanel = FilesPanel(main_window)
    update!(filespanel, pwd())
    add_side_panel(filespanel, "F")

    global workspacepanel = WorkspacePanel(main_window)
    update!(workspacepanel)
    add_side_panel(workspacepanel, "W")

    ##

    global projectspanel = ProjectsPanel(main_window)
    update!(projectspanel)
    add_side_panel(projectspanel, "P")

    ################
    ## Plots
    #GtkREPL.gadfly()

    sleep(0.01)
    figure()
    drawnow() = sleep(0.001)

    init!(pathCBox)#need on_path_change to be defined

    signal_connect(sidePanelButton_clicked_cb, sidePanelButton, "clicked", Nothing, (), false)
    signal_connect(editorButtonclicked_cb, editorButton, "clicked", Nothing, (), false)

    showall(main_window)
    visible(search_window, false)
    visible(sidepanel_ntbook, false)
    visible(editor.sourcemap, opt("Editor", "show_source_map"))

    ## starting task and such

    sleep(0.01)

    if REDIRECT_STDOUT

        global stdout_ = stdout
        global stderr_ = stderr

        read_stdout, wr = redirect_stdout()
        #read_stderr, wre = redirect_stderr()

        function watch_stdout()
            @async GtkREPL.watch_stream(read_stdout, console)
        end
        function watch_stderr()
            @async GtkREPL.watch_stream(read_stderr, console)
        end

        global watch_stdout_task = watch_stdout()
        #global watch_stderr_task = watch_stderr()

       GtkREPL.init_stdout!(main_window.console_manager, watch_stdout_task, stdout_, stderr_)

        g_timeout_add(()->print_to_console(console), 10)
    end

    println("Warming up, hold on...")
    sleep(0.05)
    #@async logo()
    new_prompt(console)

end
