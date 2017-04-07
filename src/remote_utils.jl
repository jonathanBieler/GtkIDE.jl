#things that need to be defined on remote workers
using RemoteEval
import Base.show

Base.show(io::IO,p::Gadfly.Plot) = write(io,"Gadfly.Plot(...)")

# Compatitbily with 0.5
if !isdefined(Base,:(showlimited))
    showlimited(x) = show(x)
    showlimited(io::IO,x) = show(io,x)
else
    import Base.showlimited
end

function workspace()
    last = Core.Main
    b = last.Base
    ccall(:jl_new_main_module, Any, ())
    m = Core.Main
    ccall(:jl_add_standard_imports, Void, (Any,), m)
    eval(m,
         Expr(:toplevel,
              :(const Base = $(Expr(:quote, b))),
              :(const LastMain = $(Expr(:quote, last))),
              :(include(joinpath(Pkg.dir(),"GtkIDE","src","remote_utils.jl")))
              )
          )
    empty!(Base.package_locks)
    nothing
end

#FIXME I probably don't need the two step system here
function send_stream(rd::IO, stdout_buffer::IO)
    nb = nb_available(rd)
    if nb > 0
        d = read(rd, nb)
        s = String(copy(d))

        if !isempty(s)
            write(stdout_buffer,s)
        end
    end
end

function watch_stream(rd::IO, stdout_buffer::IO)
    while !eof(rd) # blocks until something is available
        send_stream(rd,stdout_buffer)
        sleep(0.01) # a little delay to accumulate output
    end
end

function send_to_main_worker(stdout_buffer::IO)

    while true
        s = takebuf_string(stdout_buffer)
        if !isempty(s)
            remotecall(print_to_console_remote,1,s,myid())
        end
        sleep(0.01)
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

    stdout = STDOUT
    stderr = STDERR

    read_stdout, wr = redirect_stdout()
    #read_stderr, wre = redirect_stderr()
    stdout_buffer = IOBuffer()

    watch_stdio_task = @schedule watch_stream(read_stdout,stdout_buffer)
    #watch_stderr_task = @schedule watch_stream(read_stderr,stdout_buffer)

    send_to_main_worker_task = @schedule send_to_main_worker(stdout_buffer)

end

function plot_image(m)
    image(m)
end

