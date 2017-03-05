type MainWindow <: GtkWindow

    handle::Ptr{Gtk.GObject}
    style_and_language_manager::StyleAndLanguageManager
    editor#TODO type this ? (circular def)
    console_manager
    pathCBox
    statusBar
    project

    function MainWindow()

        w = @GtkWindow("GtkIDE.jl",1800,1200)
        signal_connect(main_window_key_press_cb,w, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
        signal_connect(main_window_quit_cb, w, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

        sl_mng = StyleAndLanguageManager()
        n = new(w.handle,sl_mng)
        Gtk.gobject_move_ref(n, w)
    end
end

function init!(main_window::MainWindow,editor,c_mng,pathCBox,statusBar,project)#TODO type this ?
    main_window.editor = editor
    main_window.console_manager = c_mng
    main_window.pathCBox = pathCBox
    main_window.statusBar = statusBar
    main_window.project = project
end

## exiting
@guarded (PROPAGATE) function main_window_quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    main_window = convert(GtkWindow, widgetptr)

    if typeof(main_window.project) == Project
        save(main_window.project)
    end

    global is_running = false
    REDIRECT_STDOUT && stop_console_redirect(main_window)
    
    return PROPAGATE
end

function toggle_editor()#use visible ?
    if Gtk.G_.position(mainPan) > 0
        mainPanPos = Gtk.G_.position(mainPan)
        Gtk.G_.position(mainPan,0)
    else
        Gtk.G_.position(mainPan,650) #FIXME need a layout type to save all these things
    end
end

function main_window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)
    main_window = convert(GtkWindow, widgetptr)

    mod = get_default_mod_mask()

    if doing(Action("r",PrimaryModifier),event)
        @schedule begin
            #crashes if we are still in the callback
            sleep(0.2)
#            eval(Main,:(restart()))
            restart(main_window)
        end
    end
    if event.keyval == Gtk.GdkKeySyms.F1
        toggle_sidepanel()
    end
    if event.keyval == Gtk.GdkKeySyms.F2
        toggle_editor()
    end

    return Cint(false)
end

function sidePanelButton_clicked_cb(widgetptr::Ptr, user_data)
    toggle_sidepanel()
    return nothing
end

function editorButtonclicked_cb(widgetptr::Ptr, user_data)
    toggle_editor()
    return nothing
end

function toggle_sidepanel()
    visible(sidepanel_ntbook,!visible(sidepanel_ntbook))
end

# Not ideal, it always refresh when using the pathdisplay
function on_path_change(main_window::MainWindow,doUpdate=false)
    c_path = unsafe_string(Gtk.G_.active_text(main_window.pathCBox))
    update_pathEntry(main_window)
    if pwd() != c_path || doUpdate
        push!(main_window.pathCBox,pwd())
        isdefined(:filespanel) && update!(filespanel)#FIXME global
    end
end

##
function restart(main_window::MainWindow,new_workspace=false)

        println("restarting...")
        sleep(0.1)
        is_running = false

        REDIRECT_STDOUT && stop_console_redirect(main_window)

        update!(main_window.project)
        save(main_window.project)
        win_ = main_window

        new_workspace && workspace()
        destroy(win_)
#        gtkide()

        #include( joinpath(HOMEDIR,"GtkIDE.jl") )

        #Order matters
        include("MenuUtils.jl")
        include("PlotWindow.jl")
        include("StyleAndLanguageManager.jl")
        include("MainWindow.jl")
        include("Project.jl")
        include("ConsoleManager.jl")
        include("CommandHistory.jl")
        include("Console.jl")
        include("Editor.jl")
        include("NtbookUtils.jl")
        include("PathDisplay.jl")
        include("MainMenu.jl")
        include("SidePanels.jl")

        include("init.jl")
        __init__()

end

function run_tests()
    include( joinpath(Pkg.dir(),"GtkIDE","test","runtests.jl") )
end
