## special commands that can be called from the console
# FIXME evaluate in console

type Console_command
	r::Regex
	f::Function
	completion_context::Symbol
end

global console_commands = Array(Console_command,0)
add_console_command(r::Regex,f::Function) = push!(console_commands,Console_command(r,f,:normal))
add_console_command(r::Regex,f::Function,c::Symbol) = push!(console_commands,Console_command(r,f,c))

add_console_command(r"^edit (.*)",(m) -> begin
    open_in_new_tab(m.captures[1])
    clear_entry()
    return true
end,:file)
add_console_command(r"^$",(m) -> begin
    write(console,"\n")
    return true
end)
add_console_command(r"^clc$",(m) -> begin
    clear(console)
    return true
end)
add_console_command(r"^pwd",(m) -> begin
    write(console,"\n$(pwd())\n")
    clear_entry()
    return true
end)
add_console_command(r"^ls\s*(.*)",(m) -> begin

	try
        files = m.captures[1] == "" ? readdir() : readdir(m.captures[1])
        s = ""
        for f in files
            s = string(s,"\n",f)
        end
        write(console, s * "\n")
	catch err
		write(console,sprint(show,err) * "\n")
	end

    clear_entry()
    return true
end,:file)

add_console_command(r"^cd (.*)",(m) -> begin
	try
	    cd(m.captures[1])
		write(console,"\n$(pwd())\n")
	catch err
		write(console,sprint(show,err) * "\n")
	end
    clear_entry()
    return true
end,:file)

function console_commands_context(cmd::AbstractString)
    for c in console_commands
        m = match(c.r,cmd)
        if m != nothing
            return (c.completion_context,m)
        end
    end
    return (:normal,nothing)
end

function check_console_commands(cmd::AbstractString)
    for c in console_commands
        m = match(c.r,cmd)
        if m != nothing
            return c.f(m)
        end
    end
    return false
end
