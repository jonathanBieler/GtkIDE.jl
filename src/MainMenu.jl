##
function quitMenuItem_activate_cb(widgetptr::Ptr, user_data)
    #widget = convert(GtkMenuItem, widgetptr)
    destroy(win)
    return nothing
end
function newMenuItem_activate_cb(widgetptr::Ptr, user_data)
    add_tab()
    save(project)##FIXME this souldn't be here
    return nothing
end
function openMenuItem_activate_cb(widgetptr::Ptr, user_data)
    openfile_dialog()
    return nothing
end

function openREADME_MenuItem_activate_cb(widgetptr::Ptr, user_data)
    open_in_new_tab(joinpath(HOMEDIR,"..","README.md"))
    nothing
end
function user_settings_MenuItem_activate_cb(widgetptr::Ptr, user_data)
    open_in_new_tab(joinpath(HOMEDIR,"config","user_settings.ini"))
    nothing
end

##

menubar = @GtkMenuBar() |>
    (fileMenu = @GtkMenuItem("_File")) |>
    (settingsMenu= @GtkMenuItem("_Settings"))|>
    (helpMenu = @GtkMenuItem("_Help"))

buildmenu([
    MenuItem("New File",newMenuItem_activate_cb),
    MenuItem("Open File",openMenuItem_activate_cb),
    GtkSeparatorMenuItem,
    MenuItem("Quit",quitMenuItem_activate_cb),
    ],
    fileMenu,
    ()
)

#Settings
buildmenu([
    MenuItem("User Settings",user_settings_MenuItem_activate_cb),
    ],
    settingsMenu,
    ()
)

# Help
buildmenu([
    MenuItem("README",openREADME_MenuItem_activate_cb),
    ],
    helpMenu,
    ()
)


    
