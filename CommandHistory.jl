type HistoryProvider
    history::Array{AbstractString,1}
    filename::AbstractString
    cur_idx::Int
    HistoryProvider() = new(AbstractString[""],nothing,0,0)
    HistoryProvider(h::Array{AbstractString,1},hf,cidx::Int) = new(h,hf,cidx)
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
##
function history_move(h::HistoryProvider,m::Int)
    h.cur_idx = clamp(h.cur_idx+m,1,length(h.history)+1) #+1 is the empty state when we are at the end of history and press down
end
history_get_current(h::HistoryProvider) = h.cur_idx == length(h.history)+1 ? "" : h.history[h.cur_idx]
function history_seek_end(h::HistoryProvider)
    h.cur_idx = length(h.history)+1
end
