##
function quitMenuItem_activate_cb(widgetptr::Ptr, user_data)
    #widget = convert(GtkMenuItem, widgetptr)
    main_window = user_data
    destroy(main_window)#TODO global
    return nothing
end
function newMenuItem_activate_cb(widgetptr::Ptr, user_data)
    main_window = user_data
    add_tab(main_window.editor)
    save(project)##FIXME this souldn't be here
    return nothing
end
function openMenuItem_activate_cb(widgetptr::Ptr, user_data)
    main_window = user_data
    openfile_dialog(main_window.editor)
    return nothing
end

function openREADME_MenuItem_activate_cb(widgetptr::Ptr, user_data)
    main_window = user_data
    open_in_new_tab(joinpath(HOMEDIR,"..","README.md"),main_window.editor)
    nothing
end
function user_settings_MenuItem_activate_cb(widgetptr::Ptr, user_data)
    main_window = user_data
    open_in_new_tab(joinpath(HOMEDIR,"config","user_settings.ini"),main_window.editor)
    nothing
end

##

function MainMenu(main_window::MainWindow)

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
        (main_window)
    )

    #Settings
    buildmenu([
        MenuItem("User Settings",user_settings_MenuItem_activate_cb),
        ],
        settingsMenu,
        (main_window)
    )

    # Help
    buildmenu([
        MenuItem("README",openREADME_MenuItem_activate_cb),
        ],
        helpMenu,
        (main_window)
    )
    return menubar
end
