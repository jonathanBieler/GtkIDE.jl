include("CommandHistory.jl")

type Console <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    run_task::Task
    prompt_position::Integer
    stdout_buffer::IOBuffer
    worker_idx::Int
    run_worker::RemoteRef
    history::HistoryProvider

    function Console(w_idx::Int)

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
        #setproperty!(v,:expand,true)

        setproperty!(v,:tab_width,4)
        setproperty!(v,:insert_spaces_instead_of_tabs,true)

        setproperty!(v,:margin_bottom,10)

        sc = @GtkScrolledWindow()
        setproperty!(sc,:hscrollbar_policy,1)

        push!(sc,v)
        showall(sc)

        push!(Gtk.G_.style_context(v), provider, 600)
        t = @schedule begin end

        if nprocs() == 1
            addprocs(1)
        end
        remotecall_wait(2,
            ()->include("remote_utils.jl")
        )

        history = setup_history(w_idx)

        n = new(sc.handle,v,b,t,1,IOBuffer(),w_idx,RemoteRef(),history)
        Gtk.gobject_move_ref(n, sc)
    end
end

const console = Console(1)

include("ConsoleCommands.jl")

import Base.write
function write(c::Console,str::AbstractString,set_prompt=false)

    if set_prompt
        insert!(c.buffer,end_iter(c.buffer),"\n>")
        c.prompt_position = length(c.buffer)+1

        it = GtkTextIter(c.buffer,c.prompt_position-1)
        insert!(c.buffer, it,str)
#        c.prompt_position = length(c.buffer)+1
        c.prompt_position += length(str)
        text_buffer_place_cursor(c.buffer,end_iter(c.buffer))
    else

        it = GtkTextIter(c.buffer,c.prompt_position-1)
        insert!(c.buffer, it,str)
        c.prompt_position += length(str)

        it = GtkTextIter(c.buffer,c.prompt_position-1)
        if get_text_left_of_iter(it) != "\n"
            insert!(c.buffer,it,"\n")
            c.prompt_position += 1
        end

    end
end
write(c::Console,x,set_prompt=false) = write(c,string(x),set_prompt)

function clear(c::Console)
    setproperty!(c.buffer,:text,"")
    new_prompt(c)
end
##

function on_return(c::Console,cmd::AbstractString)

    cmd = strip(cmd)
    buffer = c.buffer

    history_add(c.history,cmd)
    history_seek_end(c.history)

    #write(c,"\n")

    (found,t) = check_console_commands(cmd)

    if found
    else

        ref = remotecall(c.worker_idx,eval_command_remotely,cmd)
        t = @schedule begin fetch(ref) end
#        t = eval_command_locally(cmd)

    end
    console.run_task = t

    @schedule write_output_to_console(c)

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


function eval_command_locally(cmd::AbstractString)

    ex = Base.parse_input_line(cmd)
    ex = expand(ex)

    evalout = ""
    v = :()

    t = @schedule begin
        try
            v = eval(Main,ex)
            eval(Main, :(ans = $(Expr(:quote, v))))

            if typeof(v) <: Gadfly.Plot
                display(v)
            end
            evalout = v == nothing ? "" : sprint(showlimited,v)
        catch err
            bt = catch_backtrace()
            evalout = sprint(showerror,err,bt)
        end

        finalOutput = evalout == "" ? "" : "$evalout\n"

        return finalOutput, v
    end
    return t
end

function write_output_to_console(c::Console)

    t = c.run_task
    wait(t)
#    sleep(0.1)#wait for prints

    if t.result != nothing
        str, v = t.result
        finalOutput = str == nothing ? "" : str
        write(c,finalOutput,true)

        if typeof(v) <: Gadfly.Plot
            display(v)
        end
    end
    on_path_change()

end


##

function prompt(c::Console)

    its = GtkTextIter(c.buffer,c.prompt_position)
    ite = GtkTextIter(c.buffer,length(c.buffer)+1)
    cmd = text_iter_get_text(its,ite)

    return cmd
end
function prompt(c::Console,str::AbstractString,offset::Integer)

    its = GtkTextIter(c.buffer,c.prompt_position)
    ite = GtkTextIter(c.buffer,length(c.buffer)+1)
    replace_text(c.buffer,its,ite, str)
    if offset >= 0 && c.prompt_position+offset-1 <= length(c.buffer)
        text_buffer_place_cursor(c.buffer,c.prompt_position+offset-1)
    end

end
prompt(c::Console,str::AbstractString) = prompt(c,str,-1)
new_prompt(c::Console) = write(c,"",true)

function move_cursor_to_end(c::Console)
    text_buffer_place_cursor(c.buffer,end_iter(c.buffer))
end

#return cursor position in the prompt text
function cursor_position(c::Console)
    a = c.prompt_position
    b = cursor_position(c.buffer)
    b-a+1
end

##
ismodkey(event::Gtk.GdkEvent,mod::Integer) =
    any(x -> Int(x) == Int(event.keyval),[
        Gtk.GdkKeySyms.Control_L, Gtk.GdkKeySyms.Control_R,
        Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        Gtk.GdkKeySyms.Hyper_L,Gtk.GdkKeySyms.Hyper_R,
        Gtk.GdkKeySyms.Shift_L,Gtk.GdkKeySyms.Shift_R
    ]) ||
    any(x -> Int(x) == Int(event.state & mod),[
        GdkModifierType.CONTROL,Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        PrimaryModifier, GdkModifierType.SHIFT, GdkModifierType.GDK_MOD1_MASK])


#FIXME disable drag and drop text above cursor
# ctrl-a to clear prompt

@guarded (INTERRUPT) function console_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
#    widget = convert(GtkSourceView, widgetptr)

    event = convert(Gtk.GdkEvent, eventptr)
    console = user_data
    buffer = console.buffer

    cmd = prompt(console)
    pos = cursor_position(console)
    prefix = length(cmd) >= pos ? cmd[1:pos] : ""

    mod = get_default_mod_mask()

    #FIXME put this elsewhere?
    before_prompt(pos::Integer) = pos+1 < console.prompt_position
    before_prompt() = before_prompt( getproperty(buffer,:cursor_position,Int) )

    before_or_at_prompt(pos::Integer) = pos+1 <= console.prompt_position
    before_or_at_prompt() = before_or_at_prompt(getproperty(buffer,:cursor_position,Int))
    at_prompt(pos::Integer) = pos+1 == console.prompt_position

    #put back the cursor after the prompt
    if before_prompt()
        #check that we are not trying to copy or something of the sort
        if !ismodkey(event,mod)
            move_cursor_to_end(console)
        end
    end

    (found,it_start,it_end) = selection_bounds(buffer)

    if event.keyval == Gtk.GdkKeySyms.BackSpace ||
       event.keyval == Gtk.GdkKeySyms.Delete ||
       event.keyval == Gtk.GdkKeySyms.Clear

        if found
            before_prompt(offset(it_start)) && return INTERRUPT
        else
            before_or_at_prompt() && return INTERRUPT
        end
    end
    if event.keyval == Gtk.GdkKeySyms.Left
        if found
            at_prompt(offset(it_start)) && return INTERRUPT
            return PROPAGATE
        else
            before_or_at_prompt() && return INTERRUPT
        end
    end

    if event.keyval == Gtk.GdkKeySyms.Return

        if console.run_task.state == :done
            on_return(console,cmd)
        end
        return INTERRUPT
    end

    if event.keyval == Gtk.GdkKeySyms.Up
        if found
            if !before_prompt(offset(it_start))
                selection_bounds(buffer,GtkTextIter(buffer,console.prompt_position),nonmutable(buffer,it_end))
                return INTERRUPT
            end
            return PROPAGATE
        end
        !history_up(console.history,prefix,cmd) && return convert(Cint,true)
        prompt(console,history_get_current(console.history),length(prefix))

        return INTERRUPT
    end
    if event.keyval == Gtk.GdkKeySyms.Down
        hasselection(buffer) && return PROPAGATE
        history_down(console.history,prefix,cmd)
        prompt(console, history_get_current(console.history),length(prefix))

        return INTERRUPT
    end

    if event.keyval == Gtk.GdkKeySyms.Tab
        #convert cursor position into index
        pos = clamp(pos+1,1,length(cmd))
        autocomplete(console,cmd,pos)
        return INTERRUPT
    end

    if doing(Actions.interrupt_run,event)
        kill_current_task(console)
        return INTERRUPT
    end

    return PROPAGATE
end
signal_connect(console_key_press_cb, console.view, "key-press-event",
Cint, (Ptr{Gtk.GdkEvent},), false,console)

## MOUSE CLICKS

@guarded (INTERRUPT) function _console_button_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)
    buffer = getproperty(textview,:buffer,GtkTextBuffer)

    if event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        select_word_double_click(textview,buffer,Int(event.x),Int(event.y))
        return INTERRUPT
    end

    mod = get_default_mod_mask()
    if Int(event.button) == 1 && Int(event.state & mod) == Int(PrimaryModifier)
        open_method(textview) && return INTERRUPT
    end

    return PROPAGATE
end
signal_connect(_console_button_press_cb,console.view, "button-press-event",
Cint, (Ptr{Gtk.GdkEvent},),false,console)

global console_mousepos = zeros(Int,2)
global console_mousepos_root = zeros(Int,2)

#FIXME replace this by the same thing at the window level ?
#or put this as a field of the type.
function console_motion_notify_event_cb(widget::Ptr,  eventptr::Ptr, user_data)
    event = convert(Gtk.GdkEvent, eventptr)

    console_mousepos[1] = round(Int,event.x)
    console_mousepos[2] = round(Int,event.y)
    console_mousepos_root[1] = round(Int,event.x_root)
    console_mousepos_root[2] = round(Int,event.y_root)
    return PROPAGATE
end
signal_connect(console_motion_notify_event_cb,console,"motion-notify-event",Cint, (Ptr{Gtk.GdkEvent},), false)

##

## auto-scroll the textview
function console_scroll_cb(widgetptr::Ptr, rectptr::Ptr, user_data)

    c = user_data
    adj = getproperty(c,:vadjustment, GtkAdjustment)
    setproperty!(adj,:value,
        getproperty(adj,:upper,AbstractFloat) -
        getproperty(adj,:page_size,AbstractFloat)
    )
    adj = getproperty(c,:hadjustment, GtkAdjustment)
    setproperty!(adj,:value,0)

    nothing
end
signal_connect(console_scroll_cb, console.view, "size-allocate", Void,
    (Ptr{Gtk.GdkRectangle},), false,console)

## Auto-complete

function autocomplete(c::Console,cmd::AbstractString,pos::Integer)

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

function update_completions(c::Console,comp,dotpos,cmd,firstpart)

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
        #write(c,out,true)
        println(out)
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

function kill_current_task(c::Console)
    try #otherwise this makes the callback fail in some versions
        Base.throwto(c.run_task,InterruptException())
    end
end

##


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

function watch_stream(rd::IO, c::Console)
    while !eof(rd) # blocks until something is available
        send_stream(rd,c.stdout_buffer)
        sleep(0.01) # a little delay to accumulate output
    end
end

if REDIRECT_STDOUT

    stdout = STDOUT
    stderr = STDERR

    read_stdout, wr = redirect_stdout()

    function watch_stdio()
        @schedule watch_stream(read_stdout,console)
    end

    function print_to_console(user_data)

        console = unsafe_pointer_to_objref(user_data)

        s = takebuf_string(console.stdout_buffer)
        if !isempty(s)
            write(console,s)
        end

        if is_running
            return Cint(true)
        else
            return Cint(false)
        end
    end

    watch_stdio_tastk = watch_stdio()

    g_timeout_add(100,print_to_console,console)
end

function stop_console_redirect(t::Task,out,err)

    try
        Base.throwto(t, InterruptException())
    end
    redirect_stdout(out)
    redirect_stderr(err)
end


##
