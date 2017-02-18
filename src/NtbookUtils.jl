function close_tab(n::GtkNotebook,idx::Integer)
    splice!(n,idx)
    set_current_page_idx(n,max(idx-1,0))
end
close_tab(n::GtkNotebook) = close_tab(n,index(n))

get_current_tab(n::GtkNotebook) = n[index(n)]

@guarded (nothing) function ntbook_close_tab_cb(btn::Ptr, user_data)
    ntbook, tab = user_data
    close_tab(ntbook,index(ntbook,tab))
    return nothing
end

##