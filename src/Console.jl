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
