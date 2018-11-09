""" custom add_remote_console_cb callback that apply GtkIDE's style"""
function add_remote_console_cb(id, port)
    @info "GtkREPL: Starting console for port $port with id $id"

    c = try
        w = connect(port)

        lang = main_window.style_and_language_manager.languageDefinitions[".jl"]
        c = Console{GtkSourceView,GtkSourceBuffer}(id,main_window,w,(v,b)->init_console!(v,b,main_window),(lang,))
        GtkREPL.init!(c)

        c.worker_port = port
        GtkREPL.init!(c)

        #for some reason I need to warm-up things here, otherwise it bugs later on.
        GtkREPL.isdone(c)
        @assert remotecall_fetch(identity,GtkREPL.worker(c),1) == 1

        showall(main_window)
        c
    catch err
        warn(err)
    end

    remotecall_fetch(println, worker(c),"Worker connected")
    "done"
end

#hook into GtkREPL `on_command_done`
function on_command_done(main_window::MainWindow, console)
    on_path_change(main_window)
    update!(workspacepanel)
end

#here the index in the notebook isn't updated yet, so it's important to pass `console`
GtkREPL.on_console_mng_switch_page(cm::ConsoleManager,console::Console) = begin
    on_path_change(cm.main_window,false,console)
end