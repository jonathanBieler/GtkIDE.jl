# GtkIDE.jl
GtkIDE.jl is a [Gtk-based](https://github.com/JuliaLang/Gtk.jl) IDE for [Julia](https://github.com/JuliaLang/julia) written in Julia. It includes a terminal, a plotting window and an editor.

![screenshot](data/GtkIDE.png)

## Installation

1. Install the dependencies, [Gtk.jl](https://github.com/JuliaLang/Gtk.jl), [JSON.jl](https://github.com/JuliaLang/JSON.jl), [Winston.jl](https://github.com/nolta/Winston.jl) and [GtkSourceWidget.jl](https://github.com/jonathanBieler/GtkSourceWidget.jl),

2. Configure [Winston to use Gtk](https://github.com/nolta/Winston.jl/blob/master/src/Winston.ini#L1): tk -> gtk

3. Clone the repository.

4. Run `Main.jl`

## Issues

- Print commands and error are sent to the Julia REPL by default.
- Too many issues to list.
