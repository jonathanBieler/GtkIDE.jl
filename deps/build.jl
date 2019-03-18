## make sure antialiasing is working on windows
# if Sys.iswindows()
#     @warn("Patching Gtk's settings.ini")
#     s = Pkg.dir() * "\\WinRPM\\deps\\usr\\x86_64-w64-mingw32\\sys-root\\mingw\\etc\\gtk-3.0\\"
#     if isdir(s) && !isfile(s * "settings.ini")
#         f = open(s * "settings.ini","w")
#         write(f,
# "[Settings]
# gtk-xft-antialias = 1
# gtk-xft-rgba = rgb)")
#         close(f)
#     end
# end

using Pkg
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/GtkExtensions.jl.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/RemoteGtkREPL.jl.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/JuliaWordsUtils.jl.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/GtkTextUtils.jl.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/JuliaGtk/GtkSourceWidget.jl", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/GtkREPL.jl.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/jonathanBieler/GtkMarkdownTextView.jl.git", rev="master"))