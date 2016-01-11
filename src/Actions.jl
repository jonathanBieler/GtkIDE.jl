type Action
    keyval::Integer
    state::Integer
    description::AbstractString

    Action(k::Integer,s::Integer) = new(k,s,"")
    Action(k::Integer,s::Integer,d::AbstractString) = new(k,s,d)
    Action(k::Integer,d::AbstractString) = new(k,-1,d)
    Action(k::AbstractString,s::Integer,d::AbstractString) = new(keyval(k),s,d)
end

function doing(a::Action, event::Gtk.GdkEvent)
    if a.state == -1
        return event.keyval == a.keyval
    else
        return event.keyval == a.keyval && Int(event.state) == Int(a.state)
    end
end

baremodule Actions
    using Main.Action, Main.GdkModifierType, Main.keyval, Base.call, Main.Gtk, Base.+

    const save     = Action("s", GdkModifierType.CONTROL, "Save file")
    const closetab = Action("w", GdkModifierType.CONTROL, "Close current tab")
    const newtab   = Action("n", GdkModifierType.CONTROL, "New tab")
    const datahint = Action("d", GdkModifierType.CONTROL, "Show data hint")
    const search   = Action(keyval("f"), GdkModifierType.CONTROL, "Search")
    const runline  = Action(Gtk.GdkKeySyms.Return, GdkModifierType.CONTROL + GdkModifierType.SHIFT, "Execute current line")
    const runcode  = Action(Gtk.GdkKeySyms.Return, GdkModifierType.CONTROL, "Execute code")
    const runfile  = Action(Gtk.GdkKeySyms.F5,"Run current file")
    const copy     = Action("c", GdkModifierType.CONTROL,"Copy")
    const paste    = Action("v", GdkModifierType.CONTROL,"Paste")
    const cut      = Action("x", GdkModifierType.CONTROL,"Cut")
end