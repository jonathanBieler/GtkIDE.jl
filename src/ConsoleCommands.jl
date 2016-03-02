## special commands that can be called from the console
# FIXME evaluate in console?

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
    nothing
end,:file)
add_console_command(r"^clc$",(m) -> begin
    clear(get_current_console())
    nothing
end)
add_console_command(r"^pwd",(m) -> begin
    return pwd() * "\n"
end)
add_console_command(r"^ls\s*(.*)",(m) -> begin
	try
        files = m.captures[1] == "" ? readdir() : readdir(m.captures[1])
        s = ""
        for f in files
            s = string(s,"\n",f)
        end
        println(s)
	catch err
		println(sprint(show,err))
	end
end,:file)

add_console_command(r"^cd (.*)",(m) -> begin
	try
        v = m.captures[1]
	    if !isdir(v)
	        if isdefined(Symbol(v))
	            v = eval(Symbol("HOMEDIR"))
	        end
	    end
	    cd(v)
		println(pwd())
	catch err
		println(sprint(show,err))
	end
end,:file)
add_console_command(r"^\?\s*(.*)",(m) -> begin

    try
        h = Symbol(m.captures[1])
        h = Base.doc(Base.Docs.Binding(
            Base.Docs.current_module(),h)
        )
        h = Base.Markdown.plain(h)
        print(h)
    catch err
        println(err)
    end
end)

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
            return (true, @schedule begin c.f(m) end)
        end
    end
    return (false, nothing)
end
