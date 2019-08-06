include("CompletionProviders.jl")

mutable struct CompletionWindow <: GtkWindow #FIXME not the right container?

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    content::Array{AbstractString,1}
    idx::Integer
    main_window::MainWindow
    prefix::AbstractString
    func_names::Array{AbstractString,1}#store just the name of functions, for tuple autocomplete
    mode::Symbol #keep track of which key was pressed
    provider::CompletionProvider

    function CompletionWindow(main_window::MainWindow)

        buffer = GtkSourceBuffer()
        set_gtk_property!(buffer,:text,"")
        Gtk.create_tag(buffer, "selected",font="Bold")

        textview = GtkSourceView()
        set_gtk_property!(textview,:buffer, buffer)
        set_gtk_property!(textview,:editable, false)
        set_gtk_property!(textview,:can_focus, false)
        set_gtk_property!(textview,:hexpand, true)
        set_gtk_property!(textview,:wrap_mode,0)

        completion_window = GtkWindow("",1,1,true,false)
        #set_gtk_property!(completion_window,:height_request, 100)
        push!(completion_window,textview)
        showall(completion_window)

        t = new(completion_window.handle,textview,buffer,AbstractString[],1,main_window)
        Gtk.gobject_move_ref(t, completion_window)
    end
end

##
import  Base.Multimedia.display
#function display(w::CompletionWindow)
#
#    str = ""
#    pos_start = 1
#    pos_end = 1
#    for i = 1:min(length(w.content),30)
#        pos = length(str)+1
#        str = i == 1 ? w.content[i] : str * "\n" * w.content[i]
#        if w.idx == i
#            pos_start = pos
#            pos_end = length(str)+1
#        end
#    end
#    set_gtk_property!(w.buffer,:text,str)
#    Gtk.apply_tag(w.buffer, "selected", Gtk.GtkTextIter(w.buffer,pos_start), Gtk.GtkTextIter(w.buffer,pos_end) )
#end

function display(w::CompletionWindow)

    p = w.provider
    str = ""
    pos_start = 1
    pos_end = 1
    for i = 1:min(length(p.comp),30)
        pos = length(str)+1
        str = i == 1 ? p.comp[i] : str * "\n" * p.comp[i]
        if w.idx == i
            pos_start = pos
            pos_end = length(str)+1
        end
    end
    set_gtk_property!(w.buffer,:text,str)
    Gtk.apply_tag(w.buffer, "selected", Gtk.GtkTextIter(w.buffer,pos_start), Gtk.GtkTextIter(w.buffer,pos_end) )
end
#
##
function selection_up(w::CompletionWindow)
    w.idx = w.idx > 1 ? w.idx-1 : length(w.content)
    display(w)
end
function selection_down(w::CompletionWindow)
    w.idx = w.idx < length(w.content) ? w.idx+1 : 1
    display(w)
end

#FIXME dirty hack
function remove_filename_from_methods_def(s::AbstractString)
    ex = r"(^.*\))(.*\.jl:[0-9]+$)" #remove the file/line number for methods)
    m = match(ex,s)
    s = m == nothing ? s : m[1]

    ex = r"(^.*\))(.*?at none:[0-9]+$)"
    m = match(ex,s)
    s = m == nothing ? s : m[1]

    return s
end

function update_completion_window(event::Gtk.GdkEvent, buffer::GtkTextBuffer, t)

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

            on_return(completion_window,buffer,t)
            propagate = false
        end
    else
    end
    return propagate
end

##

function on_return(w::CompletionWindow, buffer, t)
    p = w.provider
    c = current_console(w.main_window)

    #check if we are still in the right mode, and update iterators
    if !select_text(p, c, buffer, get_text_iter_at_cursor(buffer), t)
        visible(completion_window,false)
        return
    end

    if p.state <= length(p.steps)
        p.comp = p.steps[p.state]()
        p.state += 1
    else
        #this was multisteps
        if !isempty(p.steps) && p.state == length(p.steps)+1
            completions(p,t,completion_window.idx,c)
            completion_window.content = p.comp
            display(completion_window)
            p.state = p.state+1
        else
            insert(p,formatcompletion(p,completion_window.idx),buffer)
            visible(completion_window,false)
        end
    end

end

##
function update_completion_window_release(event::Gtk.GdkEvent, buffer::GtkTextBuffer, editor)

    event.keyval == Gtk.GdkKeySyms.Escape && return false
    event.keyval == Gtk.GdkKeySyms.Down && return false
    event.keyval == Gtk.GdkKeySyms.Up && return false
    event.keyval == Gtk.GdkKeySyms.Return && return false
    event.keyval == Gtk.GdkKeySyms.Tab && return false

    t = current_tab(editor)
    visible(completion_window) && init_autocomplete(t.view, t, false; key=completion_window.mode)
    return true
end

function init_completion_window(view, p::CompletionProvider; mode=:tab)
    completion_window.provider = p
    completion_window.content = p.comp
    completion_window.idx = 1
    completion_window.mode = mode
    display(completion_window)

    (x,y,h) = get_cursor_absolute_position(view)
    Gtk.G_.position(completion_window,x+h,y)
    visible(completion_window,true)

    showall(completion_window)
end

#############################################
## Add symbols from current files to completions

function clean_symbols(S::Array{Symbol,1})
    S = unique(S)
    S = map(x -> string(x), S)
    S = filter(x -> length(x) > 1, S)
    sort(S)
end

function collect_symbols(t::EditorTab)
    ##
    str = String(get_gtk_property(t.buffer,:text,AbstractString))
    S = Symbol[]

    #no searchall :'(
    pos = Int[]
    del = '\n'
    i = firstindex(str)
    for j=1:length(str)
        str[i] == del && push!(pos,i)
        i = nextind(str,i)
    end

    i = firstindex(str)
    while !(i > ncodeunits(str))#thanks Lint.jl
        try
            (ex,i) = Meta.parse(str,i)
            if ex != nothing
                S_ = collect_symbols(ex)
                if typeof(S_) == Array{Symbol,1}
                    append!(S, S_)
                elseif typeof(S_) == Symbol
                    push!(S, S_)
                else
                    @warn("collect_symbols didn't return an array of Symbol:")
                    @show S_
                end
            end
        catch err
            idx = findfirst(pos .>= i)#FIXME only give us the start of the block in which the error is
            line = idx > 0 ? idx : length(pos)

            println("error while parsing $(t.filename) in expression starting at line $line")
            println(err)

            break
        end
    end
    clean_symbols(S)
end

function collect_symbols(ex::Expr)
    S = Symbol[]
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
collect_symbols(other) = :nothing

##
function complete_additional_symbols(str,S)
    comp = String[]
    for s in S
        startswith(s,str) && push!(comp,s)
    end
    comp
end

function extcompletions(cmd,S,c::Console)

    #(comp,dotpos) = completions(cmd, endof(cmd))
    comp,dotpos = GtkREPL.completions_in_module(cmd,c)
    comp2 = complete_additional_symbols(cmd,S)

    for c in comp2
        push!(comp,c)
    end
    comp = unique(comp)

    return (comp,dotpos)
end

########################
## Tuple completion

function type_close_enough(x::DataType, t::DataType)
    typeseq(x,t) && return true
    return (x.name === t.name && !isconcretetype(t) && x <: t)
end
function type_close_enough(x::Union, t::DataType)
    typeseq(x,t) && return true
    for u in x.types
        t <: u && return true
    end
    false
end
function type_close_enough(t::DataType,x::Union)
    typeseq(x,t) && return true
    for u in x.types
        u <: t && return true
    end
    false
end
function type_close_enough(t::Union,x::Union)
    typeseq(x,t) && return true
    for u in x.types
        for v in t.types
            u <: v && return true
        end
    end
    false
end
function type_close_enough(x::TypeVar, t::DataType )
    return x.ub != Any && t == x.ub
end
#function type_close_enough(x::TypeConstructor, t::DataType)
#    return t <: x &&  x.ub != Any
#end

##


function methods_with_tuple(t::Tuple, d::Method, meths = Method[])

    if !isdefined(d.sig,:parameters) 
        return meths
    end

    x = d.sig.parameters[2:end]
    cons = Dict{Symbol,Type}()
    if length(x) == length(t)
        m = true
        for i = 1:length(x)

            if !(t[i] <: x[i]) ||
            (x[i] == Any && t[i] != Any)
                m = false
                break
            end

            #check thing like (T<:K,T<:K)
            if typeof(x[i]) == TypeVar
                if haskey(cons,x[i].name) && !(t[i] <: cons[x[i].name])
                    m = false
                    break
                end
                cons[x[i].name] = t[i]
            end
        end
        m && push!(meths, d)
    end

    return meths
end

function methods_with_tuple(t::Tuple, f::Function, meths = Method[])
    for m in methods(f)
        methods_with_tuple(t, m, meths)
    end
end

function methods_with_tuple(t::Tuple, m::Module)
    meths = Method[]
    for nm in names(m)
        if isdefined(m, nm)
            f = getfield(m, nm)
            if isa(f, Function)
                methods_with_tuple(t, f, meths)
            end
        end
    end
    return unique(meths)
end

function methods_with_tuple(t::Tuple)
    meths = Method[]
    mainmod = Main
    # find modules in Main
    for nm in names(mainmod)
        if isdefined(mainmod,nm)
            mod = getfield(mainmod, nm)
            if isa(mod, Module)
                append!(meths, methods_with_tuple(t, mod))
            end
        end
    end
    return unique(meths)
end


"
take a tuple as a string `(x,y)`, parse it and return the types in a tuple if defined
"
function tuple_to_types(tu::AbstractString,c::Console)
    args = []
    try
        ex = Meta.parse(tu)
        if typeof(ex) != Expr
            ex = Expr(:tuple,ex)
        end

        for a in ex.args
            try
                v = remotecall_fetch(Core.eval,c.worker_idx,c.eval_in,a)
                if typeof(v) <: Union{Type,TypeVar}
                    push!(args,v)
                else
                    push!(args,typeof(v))
                end
            catch err
                @warn err
                return ()
            end
        end
    catch err
        @warn err
    end
    tuple(args...)
end

##

#Gtk.G_.keep_above(completion_window,true)
