add_console_command(r::Regex, f::Function) =
    push!(GtkREPL.console_commands, ConsoleCommand(r, f, :normal))

add_console_command(r::Regex, f::Function, c::Symbol) =
    push!(GtkREPL.console_commands, ConsoleCommand(r, f, c))

#first try to match line number
function init_console_commands()

    add_console_command(r"^edit (.*):(\d+)", (m, c) -> begin
        try
            line = parse(Int, m.captures[2])
            file = normpath(strip(m.captures[1]))
            isempty(file) && return nothing
            
            file = file[1] == '~' ? remotecall_fetch(expanduser, worker(c), file) : file
            file = isabspath(file) ? file : joinpath(pwd(c), file)
            
            open_tab(file, _editor(c), line=line)
        catch err
            println("Invalid line number: $(m.captures[2])")
        end
        nothing
    end, :file)

    add_console_command(r"^edit (.*)", (m, c) -> begin
        file = normpath(strip(m.captures[1]))
        isempty(file) && return nothing
        
        file = file[1] == '~' ? remotecall_fetch(expanduser, worker(c), file) : file
        file = isabspath(file) ? file : joinpath(pwd(c), file)
        
        open_tab(file, _editor(c))
        nothing
    end, :file)

end