function add_remote_console_cb(id, port)
    info("GtkIDE: Starting console for port $port with id $id")

    c = try
        info("connecting worker to port $port")
        worker = connect(port)

        lang = main_window.style_and_language_manager.languageDefinitions[".jl"]
        c = Console{GtkSourceView,GtkSourceBuffer}(
                length(main_window.console_manager)+1,
                main_window, worker, (v,b)->init_console!(v,b,main_window),(lang,)
        )
        GtkREPL.init!(c)
        showall(main_window.console_manager)
        c
    catch err
        warn(err)
    end

    RemoteGtkREPL.remotecall_fetch(info, worker(c),"Initializing worker...")

    g_timeout_add(100,print_to_console,c)
    "done"
end

#this is called by remote workers
function print_to_console_remote(s,idx::Integer)

    #print the output to the right console
    for i = 1:length(main_window.console_manager)
        c = get_tab(main_window.console_manager,i)

        if c.worker_idx == idx
            write(c.stdout_buffer,s)
        end
    end
end