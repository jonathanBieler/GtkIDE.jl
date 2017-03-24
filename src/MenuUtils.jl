type MenuItem
    txt::AbstractString
    cb::Function
    
    function MenuItem(txt,cb)
        new(txt,cb)
    end
end

function buildmenu(items::Array,menu::GtkMenu,user_data)
    for i in items
        if typeof(i) == MenuItem
            mi = GtkMenuItem(i.txt)
            push!(menu,mi)
            signal_connect(i.cb, mi, "activate", Void,(),false,user_data)
        elseif i == GtkSeparatorMenuItem
            push!(menu,GtkSeparatorMenuItem())
        end
    end
    showall(menu)
end
buildmenu(items::Array,menuItem::GtkMenuItem,user_data) = buildmenu(items,GtkMenu(menuItem),user_data)
buildmenu(items::Array,user_data) = buildmenu(items,GtkMenu(),user_data)
buildmenu(items::MenuItem,user_data) = buildmenu([items],user_data)
