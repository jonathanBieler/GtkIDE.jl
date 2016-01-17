type _Console <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    run_task::Task
    lock::ReentrantLock
    prompt_position::Integer

    function _Console()

        lang = languageDefinitions[".jl"]

        b = @GtkSourceBuffer(lang)
        setproperty!(b,:style_scheme,style)
        v = @GtkSourceView(b)

        highlight_matching_brackets(b,true)
        setproperty!(b,:text,">")

        show_line_numbers!(v,false)
        auto_indent!(v,true)
        highlight_current_line!(v, true)
        setproperty!(v,:wrap_mode,1)

        setproperty!(v,:tab_width,4)
        setproperty!(v,:insert_spaces_instead_of_tabs,true)

        setproperty!(v,:margin_bottom,10)

        sc = @GtkScrolledWindow()
        setproperty!(sc,:hscrollbar_policy,2)

        push!(sc,v)
        showall(sc)

        push!(Gtk.G_.style_context(v), provider, 600)
        t = @async begin end
        n = new(sc.handle,v,b,t,ReentrantLock(),2)
        Gtk.gobject_move_ref(n, sc)
    end
end

_console = _Console()

include("CommandHistory.jl")
history = setup_history()
include("ConsoleCommands.jl")

import Base.lock, Base.unlock
lock(c::_Console) = lock(c.lock)
unlock(c::_Console) = unlock(c.lock)

import Base.write
function write(c::_Console,str::AbstractString,set_prompt=false)
    @async begin
        lock(c)
        try
            if set_prompt
                insert!(c.buffer, end_iter(c.buffer),str * "\n>")
                c.prompt_position = length(c.buffer)+1
                text_buffer_place_cursor(c.buffer,end_iter(c.buffer))
            else
                insert!(c.buffer, end_iter(c.buffer),str)
            end
        finally
            unlock(c)
        end
    end
end
write(c::_Console,x,set_prompt=false) = write(c,string(x),set_prompt)

function clear(c::_Console)
    @async begin
        lock(c)
        try
            setproperty!(c.buffer,:text,"")
            #c.prompt_position = 2
        finally
            unlock(c)
        end
    end
end
##


function on_return(c::_Console,cmd::AbstractString)

    cmd = strip(cmd)
    buffer = c.buffer

    history_add(history,cmd)
    history_seek_end(history)

    print("\n")

    (found,t) = check_console_commands(cmd)

    if found

    else

        ex = Base.parse_input_line(cmd)
        ex = expand(ex)

        evalout = ""
        v = :()

        t = @async begin
            try
                v = eval(Main,ex)
                eval(Main, :(ans = $(Expr(:quote, v))))
                evalout = v == nothing ? "" : sprint(Base.showlimited,v)
            catch err
                io = IOBuffer()
                showerror(io,err)
                evalout = takebuf_string(io)
                close(io)
            end

            finalOutput = evalout == "" ? "" : "$evalout\n"
            on_path_change()#if there was any cd
            return finalOutput
        end

    end
    _console.run_task = t

    @async write_output_to_console(c)

end

function write_output_to_console(c::_Console)

    t = c.run_task
    wait(t)
    sleep(0.1)#wait for prints
    finalOutput = t.result == nothing ? "" : t.result
    on_path_change()

    write(c,finalOutput,true)
end


##

function prompt(c::_Console)
    t = @async begin
        lock(c)
        cmd = ""
        try
            its = GtkTextIter(c.buffer,c.prompt_position)
            ite = GtkTextIter(c.buffer,length(c.buffer)+1)
            cmd = text_iter_get_text(its,ite)
        finally
            unlock(c)
        end
        return cmd
    end
    wait(t)
    return t.result
end
function prompt(c::_Console,str::AbstractString,offset::Integer)
    @async begin
        lock(c)
        try
            its = GtkTextIter(c.buffer,c.prompt_position)
            ite = GtkTextIter(c.buffer,length(c.buffer)+1)
            replace_text(c.buffer,its,ite, str)
            if offset >= 0 && c.prompt_position+offset-1 <= length(c.buffer)
                text_buffer_place_cursor(c.buffer,c.prompt_position+offset-1)
            end

        finally
            unlock(c)
        end
    end
end
prompt(c::_Console,str::AbstractString) = prompt(c,str,-1)

new_prompt(c::_Console) = write(c,"",true)

#return cursor position in the prompt text
function cursor_position(c::_Console)
    a = c.prompt_position
    b = cursor_position(c.buffer)
    b-a+1
end

##
ismodkey(event::Gtk.GdkEvent) =
    any(x -> Int(x) == Int(event.keyval),[
        Gtk.GdkKeySyms.Control_L, Gtk.GdkKeySyms.Control_R,
        Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        Gtk.GdkKeySyms.Hyper_L,Gtk.GdkKeySyms.Hyper_R,
        Gtk.GdkKeySyms.Shift_L,Gtk.GdkKeySyms.Shift_R
    ]) ||
    any(x -> Int(x) == Int(event.state),[
        GdkModifierType.CONTROL,Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        PrimaryModifier, GdkModifierType.SHIFT, GdkModifierType.GDK_MOD1_MASK])


function console_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
#    widget = convert(GtkSourceView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    _console = user_data

    cmd = prompt(_console)
    pos = cursor_position(_console)
    prefix = length(cmd) >= pos ? cmd[1:pos] : ""

    before_prompt() =
    getproperty(_console.buffer,:cursor_position,Int)+1 < _console.prompt_position
    before_or_at_prompt() =
    getproperty(_console.buffer,:cursor_position,Int)+1 <= _console.prompt_position

    #put back the cursor after the prompt
    if before_prompt()

        #write(_console,string(Int(event.keyval)) * "\n" )

        #chekc that we are not trying to copy or something of the sort
        if !ismodkey(event)
            text_buffer_place_cursor(_console.buffer,end_iter(_console.buffer))
        end
    end

    if event.keyval == Gtk.GdkKeySyms.BackSpace ||
       event.keyval == Gtk.GdkKeySyms.Left ||
       event.keyval == Gtk.GdkKeySyms.Delete ||
       event.keyval == Gtk.GdkKeySyms.Clear

        before_or_at_prompt() && return INTERRUPT
    end

    if event.keyval == Gtk.GdkKeySyms.Return

        if _console.run_task.state == :done
            on_return(_console,cmd)
        end
        return INTERRUPT
    end

    if event.keyval == Gtk.GdkKeySyms.Up
        !history_up(history,prefix,cmd) && return convert(Cint,true)
        prompt(_console,history_get_current(history),length(prefix))

        return INTERRUPT
    end
    if event.keyval == Gtk.GdkKeySyms.Down
        history_down(history,prefix,cmd)
        prompt(_console,history_get_current(history),length(prefix))

        return INTERRUPT
    end

    if event.keyval == Gtk.GdkKeySyms.Tab
        #convert cursor position into index
        pos = clamp(pos+1,1,length(cmd))
        autocomplete(_console,cmd,pos)
        return INTERRUPT
    end

    return PROPAGATE
end
signal_connect(console_key_press_cb, _console.view, "key-press-event",
Cint, (Ptr{Gtk.GdkEvent},), false,_console)

##

## auto-scroll the textview
function _console_scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)

    c = user_data
    adj = getproperty(c,:vadjustment, GtkAdjustment)
    setproperty!(adj,:value,
        getproperty(adj,:upper,AbstractFloat) -
        getproperty(adj,:page_size,AbstractFloat)
    )
    nothing
end
signal_connect(_console_scroll_cb, _console.view, "size-allocate", Void,
    (Ptr{Gtk.GdkRectangle},), false,_console)

## Auto-complete

function autocomplete(c::_Console,cmd::AbstractString,pos::Integer)

    isempty(cmd) && return
    pos > length(cmd) && return

    (i,j) = select_word_backward(cmd,pos,false)

    (ctx, m) = console_commands_context(cmd)

    firstpart = cmd[1:i-1]
    cmd = cmd[i:j]

    if ctx == :normal
        (comp,dotpos) = completions(cmd, endof(cmd))
    end
    if ctx == :file

        (root,file) = splitdir(m.captures[1])
        comp = Array(AbstractString,0)
        try
            S = root == "" ? readdir() : readdir(root)
            comp = complete_additional_symbols(cmd, S)
        catch err
        end
        dotpos = 1:1
    end

    update_completions(c,comp,dotpos,cmd,firstpart)
end

## print completions in console, FIXME: adjust with console width
# cmd is the word, including dots we are trying to complete
# firstpart is words that come before it

function update_completions(c::_Console,comp,dotpos,cmd,firstpart)

    isempty(comp) && return

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
        write(c,out,true)
        #warn(out)
        out = prefix * Base.LineEdit.common_prefix(comp)
    else
        out = prefix * comp[1]
    end

    #update entry
    out = firstpart * out
    out = remove_filename_from_methods_def(out)
    prompt(c,out)
    #set_position!(console.entry,endof(out))

end


##

stdout = STDOUT
stderr = STDERR
function send_stream(rd::IO, name::AbstractString,c::_Console)
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
            write(c,s)
        end
    end
end

function watch_stream(rd::IO, name::AbstractString,c::_Console)
    try
        while !eof(rd) # blocks until something is available
            send_stream(rd, name,c)
            sleep(0.05) # a little delay to accumulate output
        end
    catch e
        # the IPython manager may send us a SIGINT if the user
        # chooses to interrupt the kernel; don't crash on this
        if isa(e, InterruptException)
            #watch_stream(rd, name)
            return
        else
            rethrow()
        end
    end
end
if true
    global read_stdout
    read_stdout, wr = redirect_stdout()
    function watch_stdio()
        return @async watch_stream(read_stdout, "stdout",_console)
    end
    global console_redirect = watch_stdio()
end


##
