# put important things in a module for safety
module GtkIDEWorker

    using Reexport
    @reexport using RemoteGtkIDE

    gtkide_port = parse(Int,ARGS[1])
    global const  id = parse(Int,ARGS[2])
    port, server = RemoteGtkIDE.start_server()

    global const gtkide = connect(gtkide_port)

end

#ploting stuff
function gadfly()

    @eval begin

        RemoteGtkIDE.gadfly()

        export figure
        import Base: show, display

        show(io::IO,p::Gadfly.Plot) = write(io,"Gadfly.Plot(...)")
        function display(p::Gadfly.Plot)
            remotecall_fetch(display,GtkIDEWorker.gtkide,p)
            nothing
        end

        figure() = remotecall_fetch(RemoteGtkIDE.eval_command_remotely,GtkIDEWorker.gtkide,"figure()",Main)
        figure(i::Integer) = remotecall_fetch(RemoteGtkIDE.eval_command_remotely,GtkIDEWorker.gtkide,"figure($i)",Main)

    end
end

# finally register ourself to gtkide
RemoteGtkIDE.remotecall_fetch(include_string, GtkIDEWorker.gtkide,"
    eval(GtkIDE,:(
        add_remote_console_cb($(GtkIDEWorker.id), $(GtkIDEWorker.port)) 
    ))
")

@schedule begin
    isinteractive() && sleep(0.1)
    if !isdefined(:watch_stdio_task)

        global const stdout = STDOUT
        global const stderr = STDERR

        read_stdout, wr = redirect_stdout()
        watch_stdio_task = @schedule RemoteGtkIDE.watch_stream(read_stdout, GtkIDEWorker.gtkide, GtkIDEWorker.id )

        #read_stderr, wre = redirect_stderr()
        #watch_stderr_task = @schedule watch_stream(read_stderr,stdout_buffer)
    end
end