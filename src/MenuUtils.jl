type MenuItem
    txt::AbstractString
    cb::Function
    
    function MenuItem(txt,cb)
        new(txt,cb)
    end
end

function buildmenu(items::Array{MenuItem,1},user_data)
    menu =  @GtkMenu() 
    for i in items
        mi = @GtkMenuItem(i.txt)
        push!(menu,mi)
        signal_connect(i.cb, mi, "activate", Void,(),false,user_data)
    end
    showall(menu)
end
buildmenu(items::MenuItem,user_data) = buildmenu([items],user_data)
