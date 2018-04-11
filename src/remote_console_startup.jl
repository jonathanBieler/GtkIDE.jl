module GtkIDEWorker

using RemoteGtkIDE

gtkide_port = parse(Int,ARGS[1])
id = parse(Int,ARGS[2])
port, server = RemoteGtkIDE.start_server()

global const gtkide = connect(gtkide_port)

RemoteGtkIDE.remotecall_fetch(include_string, gtkide,"
    eval(GtkIDE,:(
        add_remote_console_cb($id, $port) 
    ))
")

end