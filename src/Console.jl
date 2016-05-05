include("CommandHistory.jl")
"
    Console <: GtkScrolledWindow

Each `Console` has an associated worker, the first `Console` runs on worker 1 alongside
Gtk and printing is handled a bit differently than for other workers."
type Console <: GtkScrolledWindow

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    run_task::Task
    prompt_position::Integer
    stdout_buffer::IOBuffer
    worker_idx::Int
    run_worker::Channel
    history::HistoryProvider
    run_task_start_time::AbstractFloat

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

        if w_idx > 1
            remotecall_wait(w_idx,
                (HOMEDIR)->begin
                    include(joinpath(HOMEDIR,"remote_utils.jl"))
                end
            ,HOMEDIR)
        end

        history = setup_history(w_idx)

        n = new(sc.handle,v,b,t,2,IOBuffer(),w_idx,Channel(),history,time())
        Gtk.gobject_move_ref(n, sc)
    end
end

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

"""
    clear(c::Console)

    Clear the console.
"""
function clear(c::Console)
    setproperty!(c.buffer,:text,"")
end
##

function on_return(c::Console,cmd::AbstractString)

    cmd = strip(cmd)
    buffer = c.buffer

    push!(c.history,cmd)
    seek_end(c.history)

    (found,t) = check_console_commands(cmd,c)

    if !found
        ref = remotecall(c.worker_idx,eval_command_remotely,cmd)
        t = @schedule fetch(ref) #I need a task here to be able to check if it's done
#        t = eval_command_locally(cmd)
    end
    c.run_task = t
    c.run_task_start_time = time()
    text(statusBar,"Busy")

    g_idle_add(write_output_to_console,c)
    nothing
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

"Wait for the running task to end and print the result in the console.
Run from Gtk main loop."
function write_output_to_console(user_data)

    c = unsafe_pointer_to_objref(user_data)
    t = c.run_task

    if t.state == :waiting#wait for task to be done
        return Cint(true)
    end

    if t.result != nothing
        if typeof(t.result) <: Tuple #console commands can return just a string
            str, v = t.result
        else
            str, v = (t.result, nothing)
        end
        finalOutput = str == nothing ? "" : str
        write(c,finalOutput,true)

        if typeof(v) <: Gadfly.Plot
            display(v)
        end
    else
        new_prompt(c)
    end
    on_path_change()
    
    t = @sprintf("%4.6f\n",time()-c.run_task_start_time)
    text(statusBar,"Run time $(t)s")
    
    return Cint(false)
end

"Get the text after the prompt >"
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

"return cursor position in the prompt text"
function cursor_position(c::Console)
    a = c.prompt_position
    b = cursor_position(c.buffer)
    b-a+1
end

##
ismodkey(event::Gtk.GdkEvent,mod::Integer) =
    any(x -> x == event.keyval,[
        Gtk.GdkKeySyms.Control_L, Gtk.GdkKeySyms.Control_R,
        Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        Gtk.GdkKeySyms.Hyper_L,Gtk.GdkKeySyms.Hyper_R,
        Gtk.GdkKeySyms.Shift_L,Gtk.GdkKeySyms.Shift_R
    ]) ||
    any(x -> x == event.state & mod,[
        GdkModifierType.CONTROL,Gtk.GdkKeySyms.Meta_L,Gtk.GdkKeySyms.Meta_R,
        PrimaryModifier, SHIFT, GdkModifierType.GDK_MOD1_MASK,
        SecondaryModifer, PrimaryModifier+SHIFT, PrimaryModifier+GdkModifierType.META])


#FIXME disable drag and drop text above cursor
@guarded (PROPAGATE) function console_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    textview = convert(GtkTextView, widgetptr)
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
        else
            before_or_at_prompt() && return INTERRUPT
        end
        return PROPAGATE
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
        autocomplete(console,cmd,pos)
        return INTERRUPT
    end
    if doing(Actions.select_all,event)#select only prompt
        its = GtkTextIter(buffer,console.prompt_position)
        ite = end_iter(buffer)
        selection_bounds(buffer,mutable(its),ite)
        return INTERRUPT
    end
    if doing(Actions.interrupt_run,event)
        kill_current_task(console)
        return INTERRUPT
    end
    if doing(Actions.copy,event)
        signal_emit(textview, "copy-clipboard", Void)
        return INTERRUPT
    end
    if doing(Actions.paste,event)
        signal_emit(textview, "paste-clipboard", Void)
        return INTERRUPT
    end

    return PROPAGATE
end

function _callback_only_for_return(widgetptr::Ptr, eventptr::Ptr, user_data)

    event = convert(Gtk.GdkEvent, eventptr)
    console = user_data
    buffer = console.buffer

    cmd = prompt(console)

    if event.keyval == Gtk.GdkKeySyms.Return

        if console.run_task.state == :done
            on_return(console,cmd)
        end
        return Cint(true)
    end
    return Cint(false)
end
cfunction(_callback_only_for_return, Cint, (Ptr{Console},Ptr{Gtk.GdkEvent},Console))

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

    if rightclick(event)
        menu = buildmenu([
            MenuItem("Close Console",remove_console_cb),
            MenuItem("Add Console",add_console_cb)
            ],
            (console_ntkbook, get_current_console())
        )
        popup(menu,event)
        return INTERRUPT
    end

    return PROPAGATE
end

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

## Auto-complete
#FIXME call completions on the right worker
function autocomplete(c::Console,cmd::AbstractString,pos::Integer)

    isempty(cmd) && return
    pos > length(cmd) && return

    scmd = SolidString(cmd)
    (i,j) = select_word_backward(pos,scmd,false)
    (ctx, m) = console_commands_context(cmd)

    firstpart = scmd[1:i-1]
    lastpart = j < length(scmd) ? scmd[j+1:end] : ""
    cmd = scmd[i:j]

    isempty(cmd) && return

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

    update_completions(c,comp,dotpos,cmd,firstpart,lastpart)
end

# cmd is the word, including dots we are trying to complete
function update_completions(c::Console,comp,dotpos,cmd,firstpart,lastpart)

    isempty(comp) && return

    dotpos = dotpos.start
    prefix = dotpos > 1 ? cmd[1:dotpos-1] : ""

    if(length(comp)>1)

        maxLength = maximum(map(length,comp))
        w = width(c.view)
        nchar_to_width(x) = 0.9*x*fontsize #TODO pango_font_metrics_get_approximate_char_width
        n_per_line = round(Int,w/nchar_to_width(maxLength))

        out = "\n"
        for i = 1:length(comp)
            spacing = repeat(" ",maxLength-length(comp[i]))
            out = "$out $(comp[i]) $spacing"
            if mod(i,n_per_line) == 0
                out = out * "\n"
            end
        end
        write(c,out)#use write instead of print so it goes to the right console
        out = prefix * Base.LineEdit.common_prefix(comp)
    else
        out = prefix * comp[1]
    end

    offset = length(firstpart) + length(out)#place the cursor after the newly inserted piece
    #update entry
    out = firstpart * out * lastpart
    out = remove_filename_from_methods_def(out)
    prompt(c,out,offset)
    #set_position!(console.entry,endof(out))

end

function kill_current_task(c::Console)
    try #otherwise this makes the callback fail in some versions
        Base.throwto(c.run_task,InterruptException())
    end
end

function init(c::Console)
    signal_connect(console_key_press_cb, c.view, "key-press-event",
    Cint, (Ptr{Gtk.GdkEvent},), false, c)
    signal_connect(_callback_only_for_return, c.view, "key-press-event",
    Cint, (Ptr{Gtk.GdkEvent},), false,c)
    signal_connect(_console_button_press_cb,c.view, "button-press-event",
    Cint, (Ptr{Gtk.GdkEvent},),false,c)
    signal_connect(console_motion_notify_event_cb,c, "motion-notify-event",
    Cint, (Ptr{Gtk.GdkEvent},), false)
    signal_connect(console_scroll_cb, c.view, "size-allocate", Void,
    (Ptr{Gtk.GdkRectangle},), false,c)
    push!(console_ntkbook,c)
    set_tab_label_text(console_ntkbook,c,"C" * string(c.worker_idx))
end

"Run from the main Gtk loop, and print to console
the content of stdout_buffer"
function print_to_console(user_data)

    console = unsafe_pointer_to_objref(user_data)

    s = takebuf_string(console.stdout_buffer)
    if !isempty(s)
        s = translate_colors(s)
        write(console,s)
    end

    if is_running
        return Cint(true)
    else
        return Cint(false)
    end
end
#cfunction(print_to_console, Cint, Ptr{Console})

#FIXME dirty hack?
function translate_colors(s::AbstractString)

    s = replace(s,"\e[1m\e[31m","* ")
    s = replace(s,"\e[1m\e[31","* ")
    s = replace(s,"\e[0m","")
    s
end

"    free_workers()
Returns the list of workers not linked to a `Console`"
function free_workers()
    w = workers()
    used_w = Array(Int,0)

    for i=1:length(console_ntkbook)
        c = console_ntkbook[i]
        push!(used_w,c.worker_idx)
    end
    setdiff(w,used_w)
end

@guarded (INTERRUPT) function console_ntkbook_button_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    ntbook = convert(GtkNotebook, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if rightclick(event)
        menu = buildmenu([
            MenuItem("Close Console",remove_console_cb),
            MenuItem("Add Console",add_console_cb)
            ],
            (ntbook, get_current_console())
        )
        popup(menu,event)
        return INTERRUPT
    end

    return PROPAGATE
end


function add_console()

    free_w = free_workers()
    if isempty(free_w)
        i = addprocs(1)[1]
    else
        i = free_w[1]
    end
    c = Console(i)
    init(c)

    g_timeout_add(100,print_to_console,c)
    c
end
@guarded (nothing) function add_console_cb(btn::Ptr, user_data)
    add_console()
    return nothing
end
@guarded (nothing) function remove_console_cb(btn::Ptr, user_data)
    ntbook, tab = user_data
    idx = index(ntbook,tab)
    if idx != 1#can't close the main console
        close_tab(ntbook,idx)
        rmprocs(tab.worker_idx)
    end
    return nothing
end

function first_console()
    c = Console(1)
    init(c)
    c
end



get_current_console() = console_ntkbook[index(console_ntkbook)]

function console_ntkbook_switch_page_cb(widgetptr::Ptr, pageptr::Ptr, pagenum::Int32, user_data)

#    page = convert(Gtk.GtkWidget, pageptr)
#    if typeof(page) == Console
#        console = page
#    end
    nothing
end

#this is called by remote workers
function print_to_console_remote(s,idx::Integer)
    #print the output to the right console
    for i = 1:length(console_ntkbook)
        c = get_tab(console_ntkbook,i)
        if c.worker_idx == idx
            write(c.stdout_buffer,s)
        end
    end
end

## REDIRECT_STDOUT for main console

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

function stop_console_redirect(t::Task,out,err)

    try
        Base.throwto(t, InterruptException())
    end
    redirect_stdout(out)
    redirect_stderr(err)
end
#
