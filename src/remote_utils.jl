#things that need to be defined on remote workers

# Compatitbily with 0.5
if !isdefined(Base,:(showlimited))
    showlimited(x) = show(x)
    showlimited(io::IO,x) = show(io,x)
else
    import Base.showlimited
end

function eval_command_remotely(cmd::AbstractString)

    ex = Base.parse_input_line(cmd)
    ex = expand(ex)

    evalout = ""
    v = :()

    try
        v = eval(Main,ex)
        eval(Main, :(ans = $(Expr(:quote, v))))

        evalout = v == nothing ? "" : sprint(showlimited,v)
    catch err
        bt = catch_backtrace()
        evalout = sprint(showerror,err,bt)
    end

    finalOutput = evalout == "" ? "" : "$evalout\n"

    return finalOutput, v
end

#FIXME I probably don't need the two step system here
function send_stream(rd::IO, stdout_buffer::IO)
    nb = nb_available(rd)
    if nb > 0
        d = readbytes(rd, nb)
        s = bytestring(d)

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
            remotecall(1,print_to_console_remote,s,myid())
        end
        sleep(0.01)
    end
end

function print_to_console_remote(s,idx::Integer)
    #print the output to the right console
    for i = 1:length(console_ntkbook)
        c = get_tab(console_ntkbook,i)
        if c.worker_idx == idx
            write(c.stdout_buffer,s)
        end
    end
end

if !isdefined(:watch_stdio_task)

    stdout = STDOUT
    stderr = STDERR

    read_stdout, wr = redirect_stdout()
    stdout_buffer = IOBuffer()

    watch_stdio_task = @schedule watch_stream(read_stdout,stdout_buffer)
    send_to_main_worker_task = @schedule send_to_main_worker(stdout_buffer)

end
