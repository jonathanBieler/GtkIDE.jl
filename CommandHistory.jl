type HistoryProvider
    history::Array{AbstractString,1}
    filename::AbstractString
    cur_idx::Int
    search_results::Array{Int,1}
    prefix::AbstractString
    idx_search::Int

    HistoryProvider() = new(AbstractString[""],nothing,0,0,[],"",1)
    HistoryProvider(h::Array{AbstractString,1},hf,cidx::Int) = new(h,hf,cidx,[],"",1)
end

function setup_history()
    #load history, etc
    h = HistoryProvider(AbstractString["x = pi"], HOMEDIR * "history", 1)

    if isfile(h.filename)
        h.history = parse_history(h)
        h.cur_idx = length(h.history)+1
    else
        f = open(h.filename,"w")
        close(f)
    end
    return h
end
function history_add(h::HistoryProvider, str::AbstractString)
    isempty(strip(str)) && return
    push!(h.history, str)

    if isfile(h.filename)
        f = open(h.filename,"a")
        str = "
# _history_entry_
$str"
        write(f, str)
        close(f)
    else
        write(console,"unable to open history file " * h.filename)
    end
end
## use JSON ?
function parse_history(h::HistoryProvider)

    f = open(h.filename,"r")
    lines = readlines(f)
    close(f)

    out = Array(AbstractString,0)
    current_command = ""
    for line in lines
        if match(r"^# _history_entry_",line) != nothing
            current_command != "" && push!(out,current_command)
            current_command = ""
        else
            current_command = string(current_command,line)
        end
    end
    current_command != "" && push!(out,current_command)
    return out
end

import Base.search
function search(h::HistoryProvider,prefix::AbstractString)

    idx = Array(Integer,0)
    for i = length(h.history):-1:1
        startswith(h.history[i],prefix) && push!(idx,i)
    end
    h.search_results = idx
    h.prefix = prefix

    return idx
end

function history_up(h::HistoryProvider,prefix::AbstractString,cmd::AbstractString)

    if length(prefix) > 0

        if prefix != h.prefix #new search

            results = search(h,prefix)
            isempty(results) && return false

            h.idx_search = 1
            h.cur_idx = results[h.idx_search]

        else  #we already searched but want to see next result

            h.idx_search = min(h.idx_search+1,length(h.search_results))
            h.cur_idx =  length(h.search_results) > 0 ? h.search_results[h.idx_search] : h.cur_idx
        end
    else
        cmd == "" && history_seek_end(h) #we go back to the end of the list
        history_move(h,-1)
    end
    return true
end

function history_down(h::HistoryProvider,prefix::AbstractString,cmd::AbstractString)

        if length(prefix) > 0
            h.idx_search = h.idx_search-1
            if h.idx_search == 0
                history_seek_end(h)
                return
            end
            h.cur_idx =  length(h.search_results) > 0 ? h.search_results[h.idx_search] : h.cur_idx
        else
            history_move(h,+1)
        end
end

##
function history_move(h::HistoryProvider,m::Int)
    h.cur_idx = clamp(h.cur_idx+m,1,length(h.history)+1) #+1 is the empty state when we are at the end of history and press down
end
history_get_current(h::HistoryProvider) = h.cur_idx == length(h.history)+1 ? "" : h.history[h.cur_idx]
function history_seek_end(h::HistoryProvider)
    h.cur_idx = length(h.history)+1
end
