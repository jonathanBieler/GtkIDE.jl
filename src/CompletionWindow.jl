type CompletionWindow <: GtkWindow #FIXME not the right container?

    handle::Ptr{Gtk.GObject}
    view::GtkSourceView
    buffer::GtkSourceBuffer
    content::Array{AbstractString,1}
    idx::Integer
    prefix::AbstractString
    func_names::Array{AbstractString,1}#store just the name of functions, for tuple autocomplete
    mode::Symbol

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
import  Base.Multimedia.display
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

function insert_autocomplete(s::AbstractString,itstart::GtkTextIters,itend::GtkTextIters,buffer::GtkTextBuffer,mode=:normal)
    s = remove_filename_from_methods_def(s)
    if mode == :normal
        replace_text(buffer,itstart,itend,s)
    end
    if mode == :tuple
        insert!(buffer,itstart,s)
    end
end

function remove_filename_from_methods_def(s::AbstractString)
    ex = r"(^.*\))( at .+\.jl:[0-9]+$)" #remove the file/line number for methods)
    m = match(ex,s)
    s = m == nothing ? s : m[1]
    return s
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

            #FIXME redundant with Editor code
            mode = :normal
            it = get_text_iter_at_cursor(buffer)
            (cmd,itstart,itend) = select_word_backward(it,buffer,false)

            if cmd == ""
                if get_text_left_of_cursor(buffer) == ")"
                    (found,tu,itstart) = select_tuple(it, buffer)
                    mode = found ? :tuple : mode
                end
            end
            if mode == :normal
                out = completion_window.prefix * completion_window.content[completion_window.idx]
                insert_autocomplete(out,itstart,itend,buffer)
            end
            if mode == :tuple
                out = completion_window.func_names[completion_window.idx]
                insert_autocomplete(out,itstart,itstart,buffer,:tuple)
            end

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
    visible(completion_window) && editor_autocomplete(t.view,t,false)
    return true
end

function build_completion_window(comp,view,prefix,mode::Symbol)

    completion_window.mode = mode
    completion_window.content = comp
    completion_window.idx = 1
    completion_window.prefix = prefix

    display(completion_window)

    (x,y,h) = get_cursor_absolute_position(view)
    Gtk.G_.position(completion_window,x+h,y)
    visible(completion_window,true)

    showall(completion_window)
end
build_completion_window(comp,view,prefix) =
build_completion_window(comp,view,prefix,:normal)
 
function build_completion_window(comp,view,prefix,func_names)
    completion_window.func_names = func_names
    build_completion_window(comp,view,prefix,:tuple)
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
    str = utf8(getproperty(t.buffer,:text,AbstractString))
    S = Array(Symbol,0)

    #no searchall :'(
    pos = Array(Integer,0)
    del = '\n'
    i = start(str)
    for j=1:length(str)
        str[i] == del && push!(pos,i)
        i = nextind(str,i)
    end

    i = start(str)
    while !done(str,i)#thanks Lint.jl
        try
            (ex,i) = parse(str,i)
            if ex != nothing
                S_ = collect_symbols(ex)
                if typeof(S_) == Array{Symbol,1}
                    append!(S, S_)
                elseif typeof(S_) == Symbol
                    push!(S, S_)
                else
                    warn("collect_symbols didn't return an array of Symbol:")
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
collect_symbols(other) = :nothing

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
    comp = unique(comp)

    return (comp,dotpos)
end

########################
## Tuple completion

import Base.typeseq
function type_close_enough(x::DataType, t::DataType)
    typeseq(x,t) && return true
    return (x.name === t.name && !isleaftype(t) && x <: t)
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
function type_close_enough(x::TypeConstructor, t::DataType)
    return t <: x &&  x.ub != Any
end

##
function methods_with_tuple(t::Tuple, f::Function, meths = Method[])

    if !isa(f.env, MethodTable)
        return meths
    end
    d = f.env.defs

    while d !== nothing
        x = d.sig.parameters
        cons = Dict{Symbol,Type}()
        if length(x) == length(t)
            m = true
            for i = 1:length(x)

                if !(t[i] <: x[i]) ||
                (x[i] == Any && t[i] != Any) ||
                (x[i] == ANY && t[i] != ANY)
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
        d = d.next
    end
    return meths
end
##

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
    mainmod = current_module()
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

#take a tuple as a string "(x,y)", parse it and return the types in a tuple if defined
function tuple_to_types(tu::AbstractString)
    args = []
    try
        ex = parse(tu)
        if typeof(ex) != Expr
            ex = Expr(:tuple,ex)
        end

        for a in ex.args
            try
                v = eval(a)
                if typeof(v) <: Union{Type,TypeVar}
                    push!(args,v)
                else
                    push!(args,typeof(v))
                end
            catch err
                return ()
            end
        end
    catch
    end
    tuple(args...)
end

##
global completion_window = CompletionWindow()
visible(completion_window,false)
#Gtk.G_.keep_above(completion_window,true)
