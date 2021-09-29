## Types
#
    abstract type CompletionProvider end

    mutable struct NoCompletion <: CompletionProvider
    end

    mutable struct NormalCompletion <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        NormalCompletion() = new(Function[], 1, "", nothing, nothing, [""], -1:0)
    end

    mutable struct MethodCompletion <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        MethodCompletion() = new(Function[], 1, "", nothing, nothing, [""], -1:0)
    end

    mutable struct ArrayCompletion2 <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        indices
        ArrayCompletion2() = new(Function[], 1, "", nothing, nothing, [""], -1:0, Int[])
    end

    mutable struct TupleCompletion <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        func_names
        TupleCompletion() = new(Function[], 1, "", nothing, nothing, [""], [""])
    end
    
    mutable struct PathCompletion <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        PathCompletion() = new(Function[], 1, "", nothing, nothing, [""], -1:0)
    end
    
    mutable struct HistoryCompletion <: CompletionProvider
        steps::Array{Function, 1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        HistoryCompletion() = new(Function[], 1, "", nothing, nothing, [""], -1:0)
    end

#end
#using CompletionProviders
##

function init_autocomplete(view::GtkTextView, t::EditorTab, replace=true; key=:tab)

    buffer = view.buffer[GtkTextBuffer]
    editor = parent(t)::Editor
    console = current_console(editor)
    
    #let's not autocomplete multiple lines
    (found, it_start, it_end) = selection_bounds(buffer)
    if found 
        GtkTextUtils.nlines(it_start, it_end) > 1 && @goto exit
    end
    
    p = get_completion_provider(console, view, t, key)
    typeof(p) == NoCompletion && @goto exit
    
    if p.state <= length(p.steps)
        p.comp = p.steps[p.state]()
        p.state += 1
    else
        completions(p, t, completion_window.idx, console)
    end
    isempty(p.comp) && @goto exit

    if length(p.comp) == 1 && replace
        insert(p, formatcompletion(p, 1), buffer)
    else
        init_completion_window(view, p; mode = key)
    end

    return INTERRUPT

    @label exit
    visible(completion_window, false)
    return PROPAGATE
end

##

function get_completion_provider(console::Console, view::GtkTextView, t::EditorTab, key=:tab)
    buffer = view.buffer[GtkTextBuffer]
    it = get_text_iter_at_cursor(buffer)

    #change providers depending on which key we used
    pts = key == :tab ? [PathCompletion, ArrayCompletion2, NormalCompletion, MethodCompletion, TupleCompletion] : [HistoryCompletion]

    for pt in pts
        p = pt()
        select_text(p, console, buffer, it, t) && return p
    end
    return NoCompletion()
end

##

function test_completion_providers()
    t = get_current_tab()
    view = t.view
    p = get_completion_provider(console, view, t)
    
    typeof(p) == NoCompletion

    buffer = view.buffer[GtkTextBuffer]
    it = get_text_iter_at_cursor(buffer)

#    completions(p, t)
    init_autocomplete(view, t)
    p
end

#p = test_completion_providers()

## Default behavior

function formatcompletion(p::CompletionProvider, idx::Int)
    p.comp[idx]
end
function insert(p::CompletionProvider, s, buffer)
    replace_text(buffer, p.itstart, p.itend, s)
end

#####################
# Normal completion

function select_text(p::NormalCompletion, console, buffer, it, t)

    istextfile(t) && return false

    (cmd, its, ite) = select_word_backward(it, buffer, false)
    cmd = strip(cmd)
    isempty(cmd) && return false
    cmd[end] == '(' && return false #trying to complete a method
    
    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
function completions(p::NormalCompletion, t, idx, c::Console)
    if !isdefined(t, :autocomplete_words)
        t.autocomplete_words = [""]
    end
    comp, dotpos = extcompletions(p.cmd, t.autocomplete_words, c)
    p.comp = comp
    p.dotpos = dotpos
end

function formatcompletion(p::NormalCompletion, idx::Int)
    dotpos = p.dotpos.start
    prefix = dotpos > 1 ? p.cmd[1:dotpos-1] : ""
    prefix * p.comp[idx]
end

function insert(p::NormalCompletion, s, buffer)
    replace_text(buffer, p.itstart, p.itend, s)
end

#####################
# Methods completion

function select_text(p::MethodCompletion, console, buffer, it, t)
    istextfile(t) && return false

    (cmd, its, ite) = select_word_backward(it, buffer, false)
    cmd = strip(cmd)
    cmd == "" && return false
    cmd[end] != '(' && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end

function completions(p::MethodCompletion, t, idx, c::Console)
    # for some reason completion removes the first module when completing methods,
    # so I take note of it here and add it back at the end
    mods = split(p.cmd, '.')
    prefix = length(mods) > 2 ? mods[1] : ""

    comp, dotpos = GtkREPL.completions_in_module(p.cmd, c)
    dotpos = dotpos .+ (lastindex(prefix)-1)
    comp = [prefix != "" ? string(prefix, '.', c) : c for c in comp]

    p.comp = comp
    p.dotpos = dotpos
end

function formatcompletion(p::MethodCompletion, idx::Int)
    s = remove_filename_from_methods_def( p.comp[idx] )
    dotpos = p.dotpos.start
    prefix = dotpos > 1 ? p.cmd[1:dotpos-1] : ""
    prefix * s
end

function insert(p::MethodCompletion, s, buffer)
    replace_text(buffer, p.itstart, p.itend, s)
end

#####################
# Array completion

function select_text(p::ArrayCompletion2, console, buffer, it, t)
    
    istextfile(t) && return false

    (cmd, its, ite) = select_word_backward(it, buffer, false)
    cmd = strip(cmd)
    cmd == "" && return false
    length(cmd) == 1 && return false #we need something before [
    cmd[end] != '[' && return false
    
    p.cmd = cmd[1:end-1]
    p.itstart = its
    p.itend = ite
    true
end

function compact_output(x)
    io = IOBuffer()
    show(IOContext(io, :compact => true, :limit => true, :displaysize => (8,20)), "text/plain", x)
    String(take!(io))
end

function completions(p::ArrayCompletion2, t, idx, c::Console)

    var = Symbol(p.cmd)
    #check if variable is defined
    !remotecall_fetch(isdefined, worker(c), c.eval_in, var) && return false
    
    ex =  :( (size = size($var), type = typeof($var)) )
    s = remotecall_fetch(Core.eval, worker(c), c.eval_in, ex)

    elems = [remotecall_fetch(Core.eval, worker(c), c.eval_in, Expr(:ref, var, i)) for i = 1:min(sum(s.size),20)]
    elems = compact_output.(elems)
    elems = [replace(e, '\n' => ' ') for e in elems]

    idx   = [CartesianIndices(s.size)[i].I for i = 1:min(sum(s.size),20)]
    elems = [string(idx, ": ", el) for (idx,el) in zip(idx,elems)]

    comp  = ["$(s.size) - $(s.type)"; string.(elems)]
    #comp = (s, string.(elems))
    p.indices = idx
    p.comp = comp
end

#TODO insert index into the brackets
function insert(p::ArrayCompletion2, s, buffer)
    replace_text(buffer, p.itend, p.itend, s)
end

function formatcompletion(p::ArrayCompletion2, idx::Int)
    idx == 1 && return "" # the first element of comp shows the size of the array
    i = p.indices[idx-1]
    string( join(i, ','), ']')
end

#####################
#Tuple completion

function select_text(p::TupleCompletion, console, buffer, it, t)
    istextfile(t) && return false

    (found, tu, itstart) = select_tuple(it, buffer)
    !found && return false

    p.cmd = tu
    p.itstart = itstart
    p.itend = itstart
    true
end

function completions(p::TupleCompletion, t, idx, c::Console)

    args = tuple_to_types(p.cmd, c)
    isempty(args) && return
    m = methods_with_tuple(args)
    comp = map(string, m)
    func_names = [string(x.name) for x in m]
    p.comp = comp
    p.func_names = func_names
end

function formatcompletion(p::TupleCompletion, idx::Int)
    p.func_names[idx]
end

function insert(p::TupleCompletion, s, buffer)
    insert!(buffer, p.itstart, s)
end

#####################
# PathCompletion

function formatcompletion(p::PathCompletion, idx::Int)
    dotpos = p.dotpos.start
    cmd = p.cmd[2:end]#remove the leading "
    prefix = dotpos > 1 ? cmd[1:dotpos-1] : ""
    
    '"' * prefix * p.comp[idx]
end

function select_text(p::PathCompletion, console, buffer, it, t)
    istextfile(t) && return false

    (cmd, its, ite) = get_current_line_text(buffer)
    ite = mutable(get_text_iter_at_cursor(buffer))
    cmd = (its:ite).text[String]
    
    cmd == "" && return false
    idx = findlast(c->c=='"', cmd)
    
    idx == nothing && return false
    idx == length(cmd) && return false 
    its += idx-1
    cmd = cmd[idx:end]
    
    #check if it's a folder
    cmd_s = strip(cmd[2:end])
    comp, dotpos = remotecall_fetch(REPL.REPLCompletions.complete_path, GtkIDE.worker(console), cmd_s, lastindex(cmd_s))
    #if not continue with normal completion
    isempty(comp) && return false
    
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end

function completions(p::PathCompletion, t, idx, c::Console)
    cmd = p.cmd
    cmd = strip(cmd[2:end])#remove the leading "
    comp, dotpos = remotecall_fetch(REPL.REPLCompletions.complete_path, worker(c), cmd, lastindex(cmd))
    comp = [c.path for c in comp]
 
    p.dotpos = dotpos
    p.comp = comp
end

#####################
# HistoryCompletion

function select_text(p::HistoryCompletion, console, buffer, it, t)

    istextfile(t) && return false

    (found, its, ite) = selection_bounds(buffer)
    if found 
        cmd = (its:ite).text[String]
    else
        #(cmd, its, ite) = select_word_backward(it, buffer, false)
        (cmd, its, ite) = get_current_line_text(buffer)
    end
    cmd = strip(cmd)
    isempty(cmd) && return false
    
    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end

function completions(p::HistoryCompletion, t, idx, c::Console)
    
    cmd = strip(p.cmd)
    idx = GtkREPL.search(c.history, cmd)

    p.dotpos = -1
    p.comp = unique(c.history.history[idx])
end

function select_text(p::HistoryCompletion, console, buffer, it, t)

    istextfile(t) && return false

    (found, its, ite) = selection_bounds(buffer)
    if found 
        cmd = (its:ite).text[String]
    else
        #(cmd, its, ite) = select_word_backward(it, buffer, false)
        # select the whole line, so it works like in the console
        (cmd, its, ite) = get_current_line_text(buffer)
    end
    cmd = strip(cmd)
    isempty(cmd) && return false
    
    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
