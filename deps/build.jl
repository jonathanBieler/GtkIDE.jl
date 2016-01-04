## make sure antialiasing is working on windows
if OS_NAME == :Windows
    warn("Patching Gtk's settings.ini")
    s = Pkg.dir() * "\\WinRPM\\deps\\usr\\x86_64-w64-mingw32\\sys-root\\mingw\\etc\\gtk-3.0\\"
    if isdir(s) && !isfile(s * "settings.ini")
        f = open(s * "settings.ini","w")
        write(f,
"[Settings]
gtk-xft-antialias = 1
gtk-xft-rgba = rgb)")
        close(f)
    end
end

warn("Patching Winston.ini")
pth = joinpath(Pkg.dir(),"Winston","src","Winston.ini")
try
    f = open(pth,"r")
    s = readall(f)
    s = replace(s, r"output_surface          = tk",
                    "output_surface          = gtk")
    close(f)

    f = open(pth,"w")
    write(f,s)
    close(f)
catch err
    warning("failed to patch Winston")
    close(f)
    rethrow(err)
end
