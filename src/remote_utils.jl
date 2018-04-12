#things that need to be defined on remote workers
#using RemoteEval
import Base: show, display

show(io::IO,p::Gadfly.Plot) = write(io,"Gadfly.Plot(...)")
function display(p::Gadfly.Plot)
    remotecall(display,1,p)
    nothing
end

# Compatitbily with 0.5
if !isdefined(Base,:(showlimited))
    showlimited(x) = show(x)
    showlimited(io::IO,x) = show(io,x)
else
    import Base.showlimited
end

function figure()
    s,v = remotecall_fetch(RemoteGtkIDE.eval_command_remotely,1,"figure()",Main)
    parse(Int,"2\n") #not ideal
end
function figure(i::Integer)
    s,v = remotecall_fetch(RemoteGtkIDE.eval_command_remotely,1,"figure($i)",Main)
    parse(Int,"2\n") #not ideal
end

function rprint(x)
    x = string(x,"\n")
    remotecall_fetch(RemoteGtkIDE.eval_command_remotely,1,
    """
        c = GtkIDE.main_window.console_manager[$(myid())]
        write(c,"$x")
    """
    ,Main)
    nothing
end


function send_stream(rd::IO)
    nb = nb_available(rd)
    if nb > 0
        d = read(rd, nb)
        s = String(copy(d))

        if !isempty(s)
            remotecall(print_to_console_remote,1,s,myid())
        end
    end
end

function watch_stream(rd::IO)
    while !eof(rd) # blocks until something is available
        send_stream(rd)
        sleep(0.01) # a little delay to accumulate output
    end
end

function print_to_console_remote(s,idx::Integer)
    #print the output to the right console
    for i = 1:length(main_window.console_manager)
        c = get_tab(main_window.console_manager,i)
        if c.worker_idx == idx
            write(c.stdout_buffer,s)
        end
    end
end

if !isdefined(:watch_stdio_task)

    global const stdout = STDOUT
    global const stderr = STDERR

    read_stdout, wr = redirect_stdout()
    #read_stderr, wre = redirect_stderr()
    
    watch_stdio_task = @schedule watch_stream(read_stdout)
    #watch_stderr_task = @schedule watch_stream(read_stderr,stdout_buffer)

end
