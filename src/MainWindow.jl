type MainWindow <: GtkWindow

    handle::Ptr{Gtk.GObject}
    style_and_language_manager::StyleAndLanguageManager
    editor#TODO type this ? (circular def)
    console_manager
    pathCBox
    statusBar
    project
    menubar
    sidepanel_ntbook

    function MainWindow()

        w = GtkWindow("GtkIDE.jl - v$(VERSION)",1800,1200)
        signal_connect(main_window_key_press_cb,w, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
        signal_connect(main_window_quit_cb, w, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

        sl_mng = StyleAndLanguageManager()
        n = new(w.handle,sl_mng)
        Gtk.gobject_move_ref(n, w)
    end
end

function init!(main_window::MainWindow,editor,c_mng,pathCBox,statusBar,project,menubar,sidepanel_ntbook)#TODO type this ?
    main_window.editor = editor
    main_window.console_manager = c_mng
    main_window.pathCBox = pathCBox
    main_window.statusBar = statusBar
    main_window.project = project
    main_window.menubar = menubar
    main_window.sidepanel_ntbook = sidepanel_ntbook
    load(main_window) #load last session
end

## exiting
@guarded (PROPAGATE) function main_window_quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    main_window = convert(GtkWindow, widgetptr)

    if typeof(main_window.project) == Project
        save(main_window.project)
    end
    save(main_window)

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

@guarded (PROPAGATE) function main_window_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)
    main_window = convert(GtkWindow, widgetptr)

    mod = get_default_mod_mask()

    if doing(Action("r",PrimaryModifier),event)
        #@schedule begin
            #crashes if we are still in the callback
            #sleep(0.2)
#            eval(Main,:(restart()))
            #restart(main_window)
        #end
    end
    if event.keyval == Gtk.GdkKeySyms.F1
        toggle_sidepanel()
    end
    if event.keyval == Gtk.GdkKeySyms.F2
        toggle_editor()
    end

    if doing(Actions["console_editor_switch"], event)
        c = current_console(main_window.console_manager).view
        if !getproperty(c,:has_focus,Bool)
            grab_focus(c)
        else
            grab_focus(current_tab(main_window.editor).view)
        end
    end

    return PROPAGATE
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
@guarded nothing function on_path_change(main_window::MainWindow,doUpdate=false)
    c_path = unsafe_string(Gtk.G_.active_text(main_window.pathCBox))
    update_pathEntry(main_window)

    if pwd() != c_path || doUpdate
        push!(main_window.pathCBox,pwd())
        for panel in main_window.sidepanel_ntbook
            on_path_change(panel)
        end
        save(main_window.project)
    end
    nothing
end

function on_commands_return(main_window::MainWindow)
    update!(workspacepanel)
end

function reload()

    eval(GtkIDE,quote
    include(joinpath(HOMEDIR,"MenuUtils.jl"))
    include(joinpath(HOMEDIR,"PlotWindow.jl"))
    include(joinpath(HOMEDIR,"StyleAndLanguageManager.jl"))
    include(joinpath(HOMEDIR,"MainWindow.jl"))
    include(joinpath(HOMEDIR,"Project.jl"))
    include(joinpath(HOMEDIR,"ConsoleManager.jl"))
    include(joinpath(HOMEDIR,"CommandHistory.jl"))
    include(joinpath(HOMEDIR,"Console.jl"))
    include(joinpath(HOMEDIR,"Refactoring.jl"))
    include(joinpath(HOMEDIR,"Editor.jl"))
    include(joinpath(HOMEDIR,"NtbookUtils.jl"))
    include(joinpath(HOMEDIR,"PathDisplay.jl"))
    include(joinpath(HOMEDIR,"MainMenu.jl"))
    include(joinpath(HOMEDIR,"SidePanels.jl"))
    include(joinpath(HOMEDIR,"Logo.jl"))
    include(joinpath(HOMEDIR,"MarkdownTextView.jl"))
    end)

end

##
function restart(main_window::MainWindow,new_workspace=false)

        println("restarting...")
        sleep(0.1)
        is_running = false

        update!(main_window.project)
        save(main_window.project)

        REDIRECT_STDOUT && stop_console_redirect(main_window)

        new_workspace && workspace()
        destroy(main_window)
#        gtkide()

        #include( joinpath(HOMEDIR,"GtkIDE.jl") )

        reload()

        #include("init.jl")
        __init__()

end

function run_tests()
    include( joinpath(Pkg.dir(),"GtkIDE","test","runtests.jl") )
end


#this allows to save some info about the session
JSON.lower(w::MainWindow) = Dict(
    "project.name" => w.project.name,
 )

function save(w::MainWindow)
    !isdir( joinpath(HOMEDIR,"config") ) && mkdir( joinpath(HOMEDIR,"config") )
    open( joinpath(HOMEDIR,"config","main_window.json") ,"w") do io
        JSON.print(io,w)
    end
end

function load(w::MainWindow)
    !isdir( joinpath(HOMEDIR,"config") ) && mkdir( joinpath(HOMEDIR,"config") )
    pth = joinpath(HOMEDIR,"config","main_window.json")
    if !isfile(pth)
        w.project.name = "default"
        return
    end

    j = JSON.parsefile(pth)

    w.project.name = j["project.name"]
end
