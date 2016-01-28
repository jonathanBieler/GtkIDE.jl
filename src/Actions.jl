type Action
    keyval::Integer
    state::Integer
    description::AbstractString

    Action(k::Integer,s::Integer) = new(k,s,"")
    Action(k::Integer,s::Integer,d::AbstractString) = new(k,s,d)
    Action(k::Integer,d::AbstractString) = new(k,-1,d)
    Action(k::AbstractString,s::Integer,d::AbstractString) = new(keyval(k),s,d)
end

#FIXME https://developer.gnome.org/gtk3/unstable/checklist-modifiers.html
function doing(a::Action, event::Gtk.GdkEvent)
    if a.state == -1
        return event.keyval == a.keyval
    else
        return event.keyval == a.keyval && Int(event.state) == Int(a.state)
    end
end

#FIXME need something like PrimaryModifier for alt and ctrl on mac
baremodule Actions
    using Main.Action, Main.GdkModifierType, Main.keyval, Base.call, Main.Gtk, Base.+, Main.PrimaryModifier

    const save     = Action("s", PrimaryModifier, "Save file")
    const closetab = Action("w", PrimaryModifier, "Close current tab")
    const newtab   = Action("n", PrimaryModifier, "New tab")
    const datahint = Action("d", PrimaryModifier, "Show data hint")
    const search   = Action(keyval("f"), PrimaryModifier, "Search")
    const runline  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier + GdkModifierType.SHIFT, "Execute current line")
    const runcode  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier, "Execute code")
    const runfile  = Action(Gtk.GdkKeySyms.F5,"Run current file")
    const copy     = Action("c", PrimaryModifier,"Copy")
    const paste    = Action("v", PrimaryModifier,"Paste")
    const cut      = Action("x", PrimaryModifier,"Cut")
    const move_to_line_start    = Action("a", GdkModifierType.GDK_MOD1_MASK,"Move cursor to line start")
    const move_to_line_end      = Action("e", GdkModifierType.GDK_MOD1_MASK,"Move cursor to line end")
    const interrupt_run = Action("x", PrimaryModifier, "Interrupt current task")
    const toggle_comment = Action("t", PrimaryModifier, "Toggle comment")
end