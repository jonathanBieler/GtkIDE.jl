type CompletionWindow <: GtkWindow #FIXME not the right container?

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    content::Array{AbstractString,1}
    idx::Integer
    prefix::AbstractString

    function CompletionWindow()

        buffer = @GtkSourceBuffer()
        setproperty!(buffer,:text,"")
        Gtk.create_tag(buffer, "selected",font="Bold")

        textview = @GtkSourceView()
        setproperty!(textview,:buffer, buffer)
        setproperty!(textview,:editable, false)
        setproperty!(textview,:can_focus, false)
        setproperty!(textview,:hexpand, true)
        setproperty!(textview,:wrap_mode,0)

        completion_window = @GtkWindow("",1,1,true,false)
        #setproperty!(completion_window,:height_request, 100)
        push!(completion_window,textview)
        showall(completion_window)

        t = new(completion_window.handle,textview,buffer)
        Gtk.gobject_move_ref(t, completion_window)
    end
end

##
function display(w::CompletionWindow)

    str = ""
    pos_start = 1
    pos_end = 1
    for i = 1:min(length(w.content),30)
        pos = length(str)+1
        str = i == 1 ? w.content[i] : str * "\n" * w.content[i]
        if w.idx == i
            pos_start = pos
            pos_end = length(str)+1
        end
    end
    setproperty!(w.buffer,:text,str)
    Gtk.apply_tag(w.buffer, "selected", Gtk.GtkTextIter(w.buffer,pos_start), Gtk.GtkTextIter(w.buffer,pos_end) )
end
##
function selection_up(w::CompletionWindow)
    w.idx = w.idx > 1 ? w.idx-1 : length(w.content)
    display(w)
end
function selection_down(w::CompletionWindow)
    w.idx = w.idx < length(w.content) ? w.idx+1 : 1
    display(w)
end

function insert_autocomplete(out::AbstractString,itstart::GtkTextIters,itend::GtkTextIters,buffer::GtkTextBuffer)

        ex = r"(^.*\))( at .+\.jl:[0-9]+$)" #remove the file/line number for methods)
        m = match(ex,out)
        out = m == nothing ? out : m[1]
        replace_text(buffer,itstart,itend,out)
end

function update_completion_window(event::Gtk.GdkEvent,buffer::GtkTextBuffer)

    propagate = true

    if event.keyval == Gtk.GdkKeySyms.Escape
        visible(completion_window, false)
    elseif event.keyval == Gtk.GdkKeySyms.Up
        if visible(completion_window)
            selection_up(completion_window)
            propagate = false
        end
    elseif event.keyval == Gtk.GdkKeySyms.Down
        if visible(completion_window)
            selection_down(completion_window)
            propagate = false
        end
    elseif event.keyval == Gtk.GdkKeySyms.Return || event.keyval == Gtk.GdkKeySyms.Tab
        if visible(completion_window)
   
            (cmd,itstart,itend) = select_word_backward(get_text_iter_at_cursor(buffer),buffer,false)

            out = completion_window.prefix * completion_window.content[completion_window.idx]
            insert_autocomplete(out,itstart,itend,buffer)
            visible(completion_window,false)
            propagate = false
        end
    else

    end
    return propagate
end

function update_completion_window_release(event::Gtk.GdkEvent,buffer::GtkTextBuffer)

    #if event.keyval >= keyval("0") && event.keyval <= keyval("z")

    event.keyval == Gtk.GdkKeySyms.Escape && return false
    event.keyval == Gtk.GdkKeySyms.Down && return false
    event.keyval == Gtk.GdkKeySyms.Up && return false
    event.keyval == Gtk.GdkKeySyms.Return && return false
    event.keyval == Gtk.GdkKeySyms.Tab && return false

    t = get_current_tab()
    visible(completion_window) && editor_autocomplete(t.view,false)
    return true
end

function build_completion_window(comp,view,prefix)

    completion_window.content = comp
    completion_window.idx = 1
    completion_window.prefix = prefix

    display(completion_window)

    (x,y,h) = get_cursor_absolute_position(view)
    Gtk.G_.position(completion_window,x+h,y)
    visible(completion_window,true)

    showall(completion_window)
end

## Add symbols from current files to completions

function clean_symbols(S::Array{Symbol,1})
    S = unique(S)
    S = map(x -> string(x), S)
    S = filter(x -> length(x) > 1, S)
    sort(S)
end

function collect_symbols(t::EditorTab)
    txt = getproperty(t.buffer,:text,AbstractString)
    S = Array(Symbol,0) 
     
    for l in split(txt,"\n")
        try
            ex = parse(l)
            S = [S; collect_symbols(ex)::Array{Symbol,1}]
        end
    end
    clean_symbols(S)
end

function collect_symbols(ex::Expr)
    S = Array(Symbol,0)
    for i=1:length(ex.args)
        s  = collect_symbols(ex.args[i]) 
        if typeof(s) == Symbol
            push!(S,s)
        elseif typeof(s) == Array{Symbol,1}
            for el in s
                push!(S,el)
            end
        end
    end
    S
end
collect_symbols(s::Symbol) = s
collect_symbols(other) = nothing

##
function complete_additional_symbols(str,S)
    comp = Array(AbstractString,0)
    for s in S
        startswith(s,str) && push!(comp,s)
    end
    comp
end

function extcompletions(cmd,S)

    (comp,dotpos) = completions(cmd, endof(cmd))
    comp2 = complete_additional_symbols(cmd,S)
    
    for c in comp2
        push!(comp,c)
    end
    
    return (comp,dotpos)
end

##
global completion_window = CompletionWindow()
visible(completion_window,false)
#Gtk.G_.keep_above(completion_window,true)
