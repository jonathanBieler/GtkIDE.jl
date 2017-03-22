# methods linking MainWindow, Editor and ConsoleManager

current_console(main_window::MainWindow) = current_console(main_window.console_manager)
current_console(editor::Editor) = current_console(editor.main_window)

current_tab(editor::Editor) = editor[index(editor)]

_editor(c::Console) = _editor(c.main_window) #TODO rename
_editor(mw::MainWindow) = mw.editor::Editor

style_provider(main_window::MainWindow) = main_window.style_and_language_manager.style_provider

console_manager(main_window::MainWindow) = main_window.console_manager
console_manager(c::Console) = console_manager(c.main_window)#parent(c)::ConsoleManager

# Methods for GtkNotebook

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
