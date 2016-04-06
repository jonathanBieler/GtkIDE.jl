@osx_only begin
    const PrimaryModifier = GdkModifierType.MOD2
    const SecondaryModifer = GdkModifierType.CONTROL
end
@windows_only begin
    const PrimaryModifier = GdkModifierType.CONTROL
    const SecondaryModifer = GdkModifierType.MOD1 #alt key
end
@linux_only begin
    const PrimaryModifier = GdkModifierType.CONTROL
    const SecondaryModifer = GdkModifierType.MOD1
end
const NoModifier  = zero(typeof(PrimaryModifier))
import GdkModifierType.SHIFT

type Action
    keyval::Integer
    state::Integer
    description::AbstractString

    Action(k::Integer,s::Integer) = new(k,s,"")
    Action(k::Integer,s::Integer,d::AbstractString) = new(k,s,d)
    Action(k::Integer,d::AbstractString) = new(k,NoModifier,d)
    Action(k::AbstractString,s::Integer,d::AbstractString) = new(keyval(k),s,d)
    Action(k::AbstractString,s::Integer) = new(keyval(k),s,"")
end

#https://developer.gnome.org/gtk3/unstable/checklist-modifiers.html
function doing(a::Action, event::Gtk.GdkEvent)

    mod = get_default_mod_mask()
    #on os x, the command key is also the meta key
    @osx_only begin
        if a.state == NoModifier && event.state == NoModifier
             return event.keyval == a.keyval
        end

        if (event.keyval == a.keyval) && (event.state & mod == a.state)
            return true
        end
        return (event.keyval == a.keyval) &&
               (event.state & mod == a.state + GdkModifierType.META)
    end

    return (event.keyval == a.keyval) && (event.state & mod == a.state)
end

function rightclick(event)
    mod = get_default_mod_mask()
    return event.button == 3 || (event.button == 1 && event.state & mod == SecondaryModifer)    
end

baremodule Actions
    using Main.Action, Main.GdkModifierType, Main.keyval, Base.call, Main.Gtk, Base.+, Main.PrimaryModifier, Main.SecondaryModifer

    const save     = Action("s", PrimaryModifier, "Save file")
    const closetab = Action("w", PrimaryModifier, "Close current tab")
    const newtab   = Action("n", PrimaryModifier, "New tab")
    const datahint = Action("D", PrimaryModifier+GdkModifierType.SHIFT, "Show data hint")
    const search   = Action(keyval("f"), PrimaryModifier, "Search")
    const runline  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier + GdkModifierType.SHIFT, "Execute current line")
    const runcode  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier, "Execute code")
    const runfile  = Action(Gtk.GdkKeySyms.F5,"Run current file")
    const copy     = Action("c", PrimaryModifier,"Copy")
    const paste    = Action("v", PrimaryModifier,"Paste")
    const cut      = Action("x", PrimaryModifier,"Cut")
    const move_to_line_start = Action("a", SecondaryModifer, "Move cursor to line start")
    const move_to_line_end   = Action("e", SecondaryModifer, "Move cursor to line end")
    const delete_line = Action("k", PrimaryModifier, "Delete line")
    const duplicate_line = Action("d", PrimaryModifier, "Duplicate line")
    const toggle_comment = Action("t", PrimaryModifier, "Toggle comment")
    const undo = Action("z", PrimaryModifier, "Undo")
    const redo = Action("z", PrimaryModifier + GdkModifierType.SHIFT, "Redo")

    const select_all = Action("a", PrimaryModifier, "Select all")

    #console
    const interrupt_run = Action("x", PrimaryModifier, "Interrupt current task")

end
