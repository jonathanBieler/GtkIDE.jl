## Types
#
# module CompletionProviders
#
#     using Gtk
#     export NoCompletion, NormalCompletion, MethodCompletion, TupleCompletion, CompletionProvider,
#     WordCompletion, WordMenuCompletion,WordMenuCompletion_step1

    abstract CompletionProvider

    type NoCompletion <: CompletionProvider
    end

    type NormalCompletion <: CompletionProvider
        steps::Array{Function,1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        NormalCompletion() = new(Function[],1,"",nothing,nothing,[""],-1:0)
    end

    type MethodCompletion <: CompletionProvider
        steps::Array{Function,1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        dotpos
        MethodCompletion() = new(Function[],1,"",nothing,nothing,[""],-1:0)
    end

    type TupleCompletion <: CompletionProvider
        steps::Array{Function,1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        func_names
        TupleCompletion() = new(Function[],1,"",nothing,nothing,[""],[""])
    end
    type WordCompletion <: CompletionProvider
        steps::Array{Function,1}
        state::Int
        cmd::AbstractString
        itstart
        itend
        comp
        WordCompletion() = new(Function[],1,"",nothing,nothing,[""])
    end

    function WordMenuCompletion_step1()
        return ["search","endswith","synonyms"]
    end

    type WordMenuCompletion <: CompletionProvider
        steps::Array{Function,1}
        state::Int
        cmd::AbstractString
        last_idx::Int
        itstart
        itend
        comp
        WordMenuCompletion() = new([WordMenuCompletion_step1],1,"",1,nothing,nothing,[""])
    end

#end
#using CompletionProviders
##

function init_autocomplete(view::GtkTextView,t::EditorTab,replace=true)

    buffer = getbuffer(view)
    
    #let's not autocomplete multiple lines
    (found,it_start,it_end) = selection_bounds(buffer)
    nline = 0 
    if found 
        nlines(it_start, it_end) > 1 && @goto exit
    end
    
    it = get_text_iter_at_cursor(buffer)

    p = get_completion_provider(view,t)
    typeof(p) == NoCompletion && @goto exit

    if p.state <= length(p.steps)
        p.comp = p.steps[p.state]()
        p.state += 1
    else
        completions(p,t,completion_window.idx)
    end
    isempty(p.comp) && @goto exit

    if length(p.comp) == 1 && replace
        insert(p,formatcompletion(p,1),buffer)
    else
        init_completion_window(view,p)
    end

    return INTERRUPT

    @label exit
    visible(completion_window,false)
    return PROPAGATE
end

##



function init_completion_window(view,p::CompletionProvider)
    completion_window.provider = p
    completion_window.content = p.comp
    completion_window.idx = 1
    display(completion_window)

    (x,y,h) = get_cursor_absolute_position(view)
    Gtk.G_.position(completion_window,x+h,y)
    visible(completion_window,true)

    showall(completion_window)
end

function get_completion_provider(view::GtkTextView,t::EditorTab)
    buffer = getbuffer(view)
    it = get_text_iter_at_cursor(buffer)

    for pt in [NormalCompletion,MethodCompletion,TupleCompletion,
               WordCompletion,WordMenuCompletion]#subtypes(CompletionProviders.CompletionProvider)
        p = pt()
        select_text(p,buffer,it,t) && return p
    end
    return NoCompletion()
end

##

function test_completion_providers()
    t = get_current_tab()
    view = t.view
    p = get_completion_provider(view,t)

    typeof(p) == NoCompletion

    buffer = getbuffer(view)
    it = get_text_iter_at_cursor(buffer)

#    completions(p,t)
    init_autocomplete(view,t)
    p
end

#p = test_completion_providers()

#&(2,1)

#p

## Default behavior

function formatcompletion(p::CompletionProvider,idx::Int)
    p.comp[idx]
end
function insert(p::CompletionProvider,s,buffer)
    replace_text(buffer,p.itstart,p.itend,s)
end

#####################
# Normal completion

function select_text(p::NormalCompletion,buffer,it,t)

    istextfile(t) && return false

    (cmd,its,ite) = select_word_backward(it,buffer,false)
    cmd = strip(cmd)
    isempty(cmd) && return false
    cmd[end] == '(' && return false #trying to complete a method

    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
function completions(p::NormalCompletion,t,idx)
    if !isdefined(t,:autocomplete_words)
        t.autocomplete_words = [""]
    end
    comp,dotpos = extcompletions(p.cmd,t.autocomplete_words)
    p.comp = comp
    p.dotpos = dotpos
end

function formatcompletion(p::NormalCompletion,idx::Int)
    dotpos = p.dotpos.start
    prefix = dotpos > 1 ? p.cmd[1:dotpos-1] : ""
    prefix * p.comp[idx]
end

function insert(p::NormalCompletion,s,buffer)
    replace_text(buffer,p.itstart,p.itend,s)
end

#####################
#Methods completion

function select_text(p::MethodCompletion,buffer,it,t)
    istextfile(t) && return false

    (cmd,its,ite) = select_word_backward(it,buffer,false)
    cmd = strip(cmd)
    cmd == "" && return false
    cmd[end] != '(' && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
function completions(p::MethodCompletion,t,idx)
    comp,dotpos = completions(p.cmd, endof(p.cmd))
    p.comp = comp
    cmd = p.cmd[1:end-1]
    _comp,dotpos = completions(cmd, endof(cmd)) #bug with julia dotpos ?
    p.dotpos = dotpos
end

function formatcompletion(p::MethodCompletion,idx::Int)
    s = remove_filename_from_methods_def( p.comp[idx] )
    dotpos = p.dotpos.start
    prefix = dotpos > 1 ? p.cmd[1:dotpos-1] : ""
    prefix * s
end

function insert(p::MethodCompletion,s,buffer)
    replace_text(buffer,p.itstart,p.itend,s)
end

#####################
#Tuple completion

function select_text(p::TupleCompletion,buffer,it,t)
    istextfile(t) && return false

    (found,tu,itstart) = select_tuple(it, buffer)
    !found && return false

    p.cmd = tu
    p.itstart = itstart
    p.itend = itstart
    true
end
function completions(p::TupleCompletion,t,idx)

    args = tuple_to_types(p.cmd)
    isempty(args) && return
    m = methods_with_tuple(args)
    comp = map(string,m)
    func_names = [string(x.name) for x in m]
    p.comp = comp
    p.func_names = func_names
end
function formatcompletion(p::TupleCompletion,idx::Int)
    p.func_names[idx]
end
function insert(p::TupleCompletion,s,buffer)
    insert!(buffer,p.itstart,s)
end

# WordCompletion

function select_text(p::WordCompletion,buffer,it,t)

#    println("testing WordCompletion")
    !istextfile(t) && return false
    hasselection(t) && return false
#    println("testing WordCompletion,does't has selection")

    (cmd,its,ite) = select_word_backward(it,buffer,false)
    cmd = strip(cmd)
    isempty(cmd) && return false

    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
function completions(p::WordCompletion,t,idx)
    comp = startswith(WordsUtils.wordlist,ascii(p.cmd))
    p.comp = comp
end

# WordMenuCompletion

function select_text(p::WordMenuCompletion,buffer,it,t)

    !istextfile(t) && return false
    (found,its,ite) = selection_bounds(buffer)
    !found && return false

    cmd = text_iter_get_text(its,ite)
    cmd = strip(cmd)
    isempty(cmd) && return false

    cmd == "" && return false
    p.cmd = cmd
    p.itstart = its
    p.itend = ite
    true
end
function completions(p::WordMenuCompletion,t,idx)
    #["search","endswith","synonyms"]
    if idx == 1
        comp = search(WordsUtils.wordlist,ascii(p.cmd))
    elseif idx == 2
        comp = endswith(WordsUtils.wordlist,ascii(p.cmd))
    else
        comp = WordsUtils.synonyms(p.cmd)
    end
    p.comp = comp
end


#end

##
