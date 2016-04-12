"
    ConsoleCommand

Commands that are first executed in the console before Julia code.

- `edit filename` : open filename in the Editor. If filename does not exists it will be created instead.
- `clc` : clear the console.
- `pwd` : get the current working directory.
- `cd dirname` : set the current working directory.
- `open name` : open name with default application (e.g. `open .` opens the current directory).
- `mkdir dirname` : make a new directory.
"
type ConsoleCommand
	r::Regex
	f::Function
	completion_context::Symbol
end

const console_commands = Array(ConsoleCommand,0)
add_console_command(r::Regex,f::Function) = push!(console_commands,ConsoleCommand(r,f,:normal))
add_console_command(r::Regex,f::Function,c::Symbol) = push!(console_commands,ConsoleCommand(r,f,c))

add_console_command(r"^edit (.*)",(m,c) -> begin
    open_in_new_tab(m.captures[1])
    nothing
end,:file)
add_console_command(r"^clc$",(m,c) -> begin
    clear(get_current_console())
    nothing
end)
add_console_command(r"^pwd",(m,c) -> begin
    return pwd() * "\n"
end)
add_console_command(r"^ls\s*(.*)",(m,c) -> begin
	try
        files = m.captures[1] == "" ? readdir() : readdir(m.captures[1])
        s = ""
        for f in files
            s = string(s,f,"\n")
        end
        return s
	catch err
		return sprint(show,err) * "\n"
	end
end,:file)

add_console_command(r"^cd (.*)",(m,c) -> begin
	try
        v = m.captures[1]
	    if !isdir(v)
	        if isdefined(Symbol(v))
	            v = eval(Symbol("HOMEDIR"))
	        end
	    end
	    cd(v) 
		return pwd() * "\n"
	catch err
		return sprint(show,err) * "\n"
	end
end,:file)
add_console_command(r"^\?\s*(.*)",(m,c) -> begin
    try
        h = Symbol(m.captures[1])
        h = Base.doc(Base.Docs.Binding(
            Base.Docs.current_module(),h)
        )
        h = Base.Markdown.plain(h)
        return h
    catch err
        return sprint(show,err) * "\n"
    end
end)
add_console_command(r"^open (.*)",(m,c) -> begin
	try
        v = m.captures[1]
        @windows_only begin
            run(`cmd /c start "$v" `)
        end
        @osx_only begin
            run(`open $v`)
        end
	catch err
		return sprint(show,err) * "\n"
	end
end,:file)
add_console_command(r"^mkdir (.*)",(m,c) -> begin
	try
        v = m.captures[1]
        mkdir(v)
	catch err
		return sprint(show,err) * "\n"
	end
end,:file)

##
function console_commands_context(cmd::AbstractString)
    for c in console_commands
        m = match(c.r,cmd)
        if m != nothing
            return (c.completion_context,m)
        end
    end
    return (:normal,nothing)
end
function check_console_commands(cmd::AbstractString,c::Console)
    for co in console_commands
        m = match(co.r,cmd)
        if m != nothing
            return (true, @schedule begin co.f(m,c) end)
        end
    end
    return (false, nothing)
end
