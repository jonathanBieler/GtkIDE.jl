
type Action
    keyval::UInt32
    state::Int32
    description::AbstractString
    
    Action() = new(0,0,"")
    Action(k,s) = new(k,s,"")
    Action(k,s,d) = new(k,s,d)
end

function doing(a::Action, event::Gtk.GdkEvent)
    return event.keyval == a.keyval && Int(event.state) == a.state
end

baremodule Actions
    using Main.Action, Main.GdkModifierType, Main.keyval, Base.call, Main.Gtk, Base.+

    save     = Action(keyval("s"), GdkModifierType.CONTROL, "Save file")
    closetab = Action(keyval("w"), GdkModifierType.CONTROL, "Close current tab")
    newtab   = Action(keyval("n"), GdkModifierType.CONTROL, "New tab")
    datahint = Action(keyval("d"), GdkModifierType.CONTROL, "Show data hint")
    search   = Action(keyval("f"), GdkModifierType.CONTROL, "Search")
    runline  = Action(Gtk.GdkKeySyms.Return, GdkModifierType.CONTROL + GdkModifierType.SHIFT, "Execute current line")
    runcode  = Action(Gtk.GdkKeySyms.Return, GdkModifierType.CONTROL, "Execute code")
    
end

