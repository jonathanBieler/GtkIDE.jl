
type Console <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    entry::GtkEntry
    locked::Bool

    function Console()

        entry = @GtkEntry()
        setproperty!(entry, :text, "")

        buffer = @GtkSourceBuffer()
        setproperty!(buffer,:text,"")

        tag = Gtk.create_tag(buffer, "error", font="Normal 16")
        setproperty!(tag,:foreground,"gray")
        Gtk.apply_tag(buffer, "error", Gtk.GtkTextIter(buffer,1) , Gtk.GtkTextIter(buffer,23) )

        Gtk.create_tag(buffer, "cursor", font="Normal $fontsize",foreground="green")
        Gtk.create_tag(buffer, "plaintext", font="Normal $fontsize")

        textview = @GtkSourceView()
        setproperty!(textview,:buffer, buffer)
        setproperty!(textview,:editable, false)
        setproperty!(textview,:can_focus, false)
        setproperty!(textview,:vexpand, true)
        setproperty!(textview,:wrap_mode,1)

        console_scwindow = @GtkScrolledWindow()
        setproperty!(console_scwindow,:height_request, 100)
        push!(console_scwindow,textview)


        t = new(console_scwindow.handle,textview,buffer,entry,false)
        Gtk.gobject_move_ref(t, console_scwindow)
    end
end

import Base: lock, unlock, wait
function lock(c::Console)
    c.locked = true
end
function unlock(c::Console)
    c.locked = false
end
function wait(c::Console)
    t = @schedule begin
        while c.locked
        end
    end
    Base.wait(t)
end
import Base.write
function write(c::Console,s::String)
    @schedule begin
        wait(c)
        lock(c)
        try
            insert!(c.buffer, end_iter(c.buffer),s)
        finally
            unlock(c)
        end
    end
end
function write(c::Console,s::String,f::Function)
    @schedule begin
        wait(c)
        lock(c)
        try
            insert!(c.buffer, end_iter(c.buffer),s)
            f()
        finally
            unlock(c)
        end
    end
end
function clear(c::Console)
    @schedule begin
        wait(c)
        lock(c)
        try
            setproperty!(c.buffer,:text,"")
            clear_entry()
        finally
            unlock(c)
        end
    end
end

function set_entry_text(str::AbstractString)

    cpos = getproperty(console.entry,:cursor_position,Int)
    setproperty!(console.entry,:text,str)
    set_position!(console.entry,cpos)
end

# FIXME remove all these variables
console = Console()
entry = console.entry
textview = console.view

if REDIRECT_STDOUT

stdout = STDOUT
function send_stream(rd::IO, name::AbstractString)
    nb = nb_available(rd)
    if nb > 0
        d = readbytes(rd, nb)
        s = try
            bytestring(d)
        catch
            # FIXME: what should we do here?
            string("<ERROR: invalid UTF8 data ", d, ">")
        end
        if !isempty(s)
            write(console,s)
        end
    end
end

function watch_stream(rd::IO, name::AbstractString)
    try
        while !eof(rd) # blocks until something is available
            send_stream(rd, name)
            sleep(0.05) # a little delay to accumulate output
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            watch_stream(rd, name)
        else
            rethrow()
        end
    end
end

global read_stdout
read_stdout, wr = redirect_stdout()
function watch_stdio()
    @async watch_stream(read_stdout, "stdout")
end
watch_stdio()
#this makes get_current_line_text crash, probably because it modifies the buffer and render textIters invalid

end#REDIRECT_STDOUT

include("CommandHistory.jl")
history = setup_history()

function clear_entry()
    setproperty!(console.entry,:text,"")
end

include("ConsoleCommands.jl")

function on_return_terminal(widget::GtkEntry,cmd::String,doClear)

    cmd = strip(cmd)
    buffer = console.buffer

    history_add(history,cmd)
    history_seek_end(history)

    cmd = strip(cmd)
    if check_console_commands(cmd)
        update_pathEntry()
        return
    end

    pos_start = length(buffer)+1
    write(console,">julia $cmd\n",() -> begin
        Gtk.apply_tag(buffer, "cursor", Gtk.GtkTextIter(buffer,pos_start), Gtk.GtkTextIter(buffer,pos_start+7) )
        Gtk.apply_tag(buffer, "plaintext", Gtk.GtkTextIter(buffer,1), Gtk.GtkTextIter(buffer,length(buffer)+1) )
    end)

    ex = Base.parse_input_line(cmd)
    ex = expand(ex)

    doClear ? setproperty!(widget,:text,"") : nothing

    evalout = ""
    value = :()
    @async begin

    #(outRead, outWrite) = redirect_stdout()#capture console prints
    #(errorRead, errorWrite) = redirect_stderr()

    try
      value = eval(Main,ex)
      eval(Main, :(ans = $(Expr(:quote, value))))
      evalout = value == nothing ? "" : sprint(Base.showlimited,value)
    catch err
      io = IOBuffer()
      showerror(io,err)
      evalout = takebuf_string(io)
      close(io)
    end


    finalOutput = "$evalout\n\n";
    write(console,finalOutput)

    update_pathEntry()#if there was any cd

    end
end

clip = @GtkClipboard()

function entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    cmd = getproperty(widget,:text,AbstractString)
    cmd = strip(cmd)

    pos = getproperty(entry,:cursor_position,Int)
    prefix = length(cmd) >= pos ? cmd[1:pos] : ""

    if Int(event.keyval) == 99 && Int(event.state) == 4 #ctrl+c
        text_buffer_copy_clipboard(console.buffer,clip)
    end

    if event.keyval == Gtk.GdkKeySyms.Return
        on_return_terminal(widget,cmd,true)
    end

    if event.keyval == Gtk.GdkKeySyms.Up

        !history_up(history,prefix,cmd) && return convert(Cint,true)

        set_entry_text(history_get_current(history))
        return convert(Cint,true)
    end
    if event.keyval == Gtk.GdkKeySyms.Down

        history_down(history,prefix,cmd)

        set_entry_text(history_get_current(history))
        return convert(Cint,true)
    end

  if event.keyval == Gtk.GdkKeySyms.Tab

    (comp,dotpos) = completions(cmd, endof(cmd))
    show_completions(comp,dotpos,widget,cmd)

    return convert(Cint,true)
  end

  return convert(Cint,false)
end
signal_connect(entry_key_press_cb, entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)

 # signal_connect(entry, "grab-notify") do widget
#     println(widget, "lose focus")
# end

#print completions in console, FIXME: adjust with console width
function show_completions(comp,dotpos,widget,cmd)
    @schedule begin
        wait(console)
        lock(console)

        dotpos = dotpos.start
        prefix = dotpos > 1 ? cmd[1:dotpos-1] : ""

        if(length(comp)>1)

            maxLength = maximum(map(length,comp))
            out = "\n"
            for i=1:length(comp)
                spacing = repeat(" ",maxLength-length(comp[i]))
                out = "$out $(comp[i]) $spacing"
                if mod(i,4) == 0
                    out = out * "\n"
                end
            end
            out = out * "\n"
            insert!(console.buffer,out)
            out = prefix * Base.LineEdit.common_prefix(comp)
            setproperty!(widget,:text,out)
            set_position!(widget,endof(out))

        elseif !isempty(comp)

            out = prefix * comp[1]
            setproperty!(widget,:text,out)
            set_position!(widget,endof(out))
        end

        unlock(console)
    end
end

## scroll textview
function scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)
  adj = getproperty(console,:vadjustment, GtkAdjustment)
  setproperty!(adj,:value, getproperty(adj,:upper,FloatingPoint) - getproperty(adj,:page_size,FloatingPoint))
  nothing
end
signal_connect(scroll_cb, textview, "size-allocate", Void, (Ptr{Gtk.GdkRectangle},), false)
