__precompile__()
module Refactoring
##
import ..opt

collect_skip_one(ex::Expr) = any( ex.head .== [:call, :(=),:kw,:macrocall])
dont_collect(ex::Expr) = any( ex.head .== [:line,:using])

#function remove_type_annotation(ex::Expr) 
#    ex.head == :(::) && return ex.args[1]
#    return :nothing
#end
#remove_type_annotation(s::Symbol) = s

#get the variable name from the rhs
function assigned_var(ex::Expr) 

    if ex.head == :call #e.g. f(x,y) = x + y -> []
        return [ex.args[1]] #map(remove_type_annotation,ex.args[2:end])
    end
    
    if ex.head == :tuple # x,y = 1,2
        out = Symbol[]
        for i=1:length(ex.args) 
            push!(out,tuple_assigment(ex.args[i]))
            typeof(ex.args[i]) == Expr && ex.args[i].head == :(=) && return out
        end
        return out
    end
    typeof(ex.args[1]) == Symbol && return [ex.args[1]]
    
    ex.args[1] 
end
assigned_var(s::Symbol) = [s]

tuple_assigment(s::Symbol) = s
tuple_assigment(ex::Expr) = ex.args[1]

is_assignement(ex::Expr) = ex.head == :(=)

function is_tuple_assigment(ex::Expr)
    if ex.head == :tuple
        for i=1:length(ex.args)
             typeof(ex.args[i]) == Expr && ex.args[i].head == :(=) && return true
        end
    end
    false
end

function arguments(ex::Expr,out,assigned)

    is_assignement(ex) && push!(assigned,assigned_var(ex.args[1])...)
    is_tuple_assigment(ex) && push!(assigned,assigned_var(ex)...)
    
    if collect_skip_one(ex)
        for i = 2:length(ex.args)
            arguments(ex.args[i],out,assigned)
        end
    elseif !dont_collect(ex)
        for i = 1:length(ex.args)
            arguments(ex.args[i],out,assigned)
        end
    end
end

function arguments(ex::Expr) 
    out, assigned = Symbol[], Symbol[]
    arguments(ex,out,assigned) 
    unique(out)
end
arguments(s::Symbol,out,assigned) = !any(s .== assigned) && push!(out,s)
arguments(s::Any,out,assigned) = nothing


#ex = quote
#    f(ex::Expr,b) = a
#    ex = 1
#end
#dump(ex)
#
#arguments(ex)

## Formatting 

function indent_body(body)

    lines = split(body,"\n")
    ident_length = [length(l) - length(lstrip(l)) for l in lines]
    line_length = [length(l) for l in lines]
    
    min_ident = minimum( ident_length[line_length.>0] )

    tabw = opt("Editor","tab_width")
    pre = " "^tabw
    
    lines = [pre*l[(1+min_ident):end]  for l in lines]
    
    join(lines,"\n")
end

function extract_method(body::AbstractString)

    ex  = try 
        ex = Base.parse_input_line(body)
    catch err
        println(err)
        return ""
    end
    
    args = arguments(ex)
    if !isempty(args)
        sargs = string(args[1])
        for i=2:length(args)
            sargs = string(sargs,", ",string(args[i]))
        end
    else
        sargs = ""
    end
    
    body = indent_body(body)
        
"
function ($sargs)
$body
end
"
end


##
end


