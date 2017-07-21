## make sure antialiasing is working on windows
@static if is_windows()
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
