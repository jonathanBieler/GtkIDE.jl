type MainWindow <: GtkWindow

    handle::Ptr{Gtk.GObject}
    style_and_language_manager::StyleAndLanguageManager
    editor#TODO type this ?
    console_manager

    function MainWindow()

        w = @GtkWindow("GtkIDE.jl",1800,1200)
        signal_connect(main_window_key_press_cb,w, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
        signal_connect(main_window_quit_cb, w, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

        sl_mng = StyleAndLanguageManager()
        n = new(w.handle,sl_mng)
        Gtk.gobject_move_ref(n, w)
    end
end

function init!(main_window::MainWindow,editor,c_mng)#TODO type this ?
    main_window.editor = editor
    main_window.console_manager = c_mng
end

style_provider(main_window::MainWindow) = main_window.style_and_language_manager.style_provider

## exiting
function main_window_quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    if typeof(project) == Project
        save(project)
    end
    #REDIRECT_STDOUT && stop_console_redirect(watch_stdio_tastk,stdout,stderr)
    global is_running = false

    return convert(Cint,false)
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

    mod = get_default_mod_mask()

    if doing(Action("r",PrimaryModifier),event)
        @schedule begin
            #crashes if we are still in the callback
            sleep(0.2)
#            eval(Main,:(restart()))
            restart()
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
function on_path_change(doUpdate=false)
    c_path = unsafe_string(Gtk.G_.active_text(pathCBox))
    update_pathEntry()
    if pwd() != c_path || doUpdate
        push!(pathCBox,pwd())
        update!(filespanel)
    end
end

##
function restart(new_workspace=false)

        println("restarting...")
        sleep(0.1)
        is_running = false

        REDIRECT_STDOUT && stop_console_redirect(watch_stdout_tastk,stdout,stderr)

        update!(project)
        save(project)
        win_ = main_window

        new_workspace && workspace()
        destroy(win_)
#        gtkide()

        include( joinpath(HOMEDIR,"GtkIDE.jl") )
end

function run_tests()
    include( joinpath(Pkg.dir(),"GtkIDE","test","runtests.jl") )
end
