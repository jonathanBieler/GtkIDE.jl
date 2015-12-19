type Action
    keyval::Integer
    state::Integer
    description::AbstractString

    Action(k::Integer,s::Integer) = new(k,s,"")
    Action(k::Integer,s::Integer,d::AbstractString) = new(k,s,d)
    Action(k::AbstractString,s::Integer,d::AbstractString) = new(keyval(k),s,d)
end

function doing(a::Action, event::Gtk.GdkEvent)
    return event.keyval == a.keyval && Int(event.state) == a.state
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

end
