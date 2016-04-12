type MenuItem
    txt::AbstractString
    cb::Function
    
    function MenuItem(txt,cb)
        new(txt,cb)
    end
end

function buildmenu(items::Array,user_data)
    menu =  @GtkMenu() 
    for i in items
        if typeof(i) == MenuItem
            mi = @GtkMenuItem(i.txt)
            push!(menu,mi)
            signal_connect(i.cb, mi, "activate", Void,(),false,user_data)
        elseif i == GtkSeparatorMenuItem
            push!(menu,@GtkSeparatorMenuItem())
        end
    end
    showall(menu)
end
buildmenu(items::MenuItem,user_data) = buildmenu([items],user_data)
