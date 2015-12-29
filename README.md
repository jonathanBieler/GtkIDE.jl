# GtkIDE.jl
GtkIDE.jl is a [Gtk-based](https://github.com/JuliaLang/Gtk.jl) IDE for [Julia](https://github.com/JuliaLang/julia) written in Julia. It includes a terminal, a plotting window and an editor.

![screenshot](data/GtkIDE.png)

## Installation


1. Install [GtkSourceWidget.jl](https://github.com/jonathanBieler/GtkSourceWidget.jl)

    `Pkg.clone("https://github.com/jonathanBieler/GtkSourceWidget.jl.git")`
    `using GtkSourceWidget` 
    
2. Install the package

    `Pkg.clone("https://github.com/jonathanBieler/GtkIDE.jl.git")`
    
3. Run it

    `using GtkIDE`

## Issues

- Print commands and error are sent to the Julia REPL by default.
- Too many issues to list.
