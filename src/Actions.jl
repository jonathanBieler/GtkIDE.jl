import Gtk.GConstants.GdkModifierType, Gtk.GConstants.GdkModifierType.SHIFT

if Sys.isapple()
    global const PrimaryModifier = GdkModifierType.MOD2
    global const SecondaryModifer = GdkModifierType.CONTROL
end
if Sys.iswindows()
    global const PrimaryModifier = GdkModifierType.CONTROL
    global const SecondaryModifer = GdkModifierType.MOD1 #alt key
end
if Sys.islinux()
    global const PrimaryModifier = GdkModifierType.CONTROL
    global const SecondaryModifer = GdkModifierType.MOD1
end
global const NoModifier  = zero(typeof(PrimaryModifier))

mutable struct Action
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
    if Sys.isapple()
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

global const Actions = Dict{AbstractString}{Action}()

Actions["save"]     = Action("s", PrimaryModifier, "Save file")
Actions["open"]     = Action("o", PrimaryModifier, "Open file")
Actions["closetab"] = Action("w", PrimaryModifier, "Close current tab")
Actions["newtab"]   = Action("n", PrimaryModifier, "New tab")
Actions["datahint"] = Action("D", PrimaryModifier+GdkModifierType.SHIFT, "Show data hint")
Actions["search"]   = Action(keyval("f"), PrimaryModifier, "Search")

Actions["runline"]  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier + GdkModifierType.SHIFT, "Execute current line")
Actions["runcode"]  = Action(Gtk.GdkKeySyms.Return, PrimaryModifier, "Execute code")
Actions["runfile"]  = Action(Gtk.GdkKeySyms.F5,"Run current file")

#TODO I should allow for several shortcuts
Actions["runline_kp"]  = Action(Gtk.GdkKeySyms.KP_Enter, PrimaryModifier + GdkModifierType.SHIFT, "Execute current line")
Actions["runcode_kp"]  = Action(Gtk.GdkKeySyms.KP_Enter, PrimaryModifier, "Execute code")

Actions["copy"]     = Action("c", PrimaryModifier,"Copy")
Actions["paste"]    = Action("v", PrimaryModifier,"Paste")
Actions["cut"]      = Action("x", PrimaryModifier,"Cut")
Actions["move_to_line_start"] = Action("a", SecondaryModifer, "Move cursor to line start")
Actions["move_to_line_end"]   = Action("e", SecondaryModifer, "Move cursor to line end")
Actions["delete_line"] = Action("k", PrimaryModifier, "Delete line")
Actions["duplicate_line"] = Action("d", PrimaryModifier, "Duplicate line")
Actions["toggle_comment"] = Action("t", PrimaryModifier, "Toggle comment")
Actions["undo"] = Action("z", PrimaryModifier, "Undo")
Actions["redo"] = Action("Z", PrimaryModifier + GdkModifierType.SHIFT, "Redo")
Actions["goto_line"] = Action("g", PrimaryModifier, "Go to line")

Actions["select_all"] = Action("a", PrimaryModifier, "Select all")

##
Actions["extract_method"] = Action("e", PrimaryModifier, "Extract method")

#console
Actions["interrupt_run"] = Action("x", SecondaryModifer, "Interrupt current task")
Actions["clear_console"] = Action("k", PrimaryModifier, "Clear Console")

#main window

# § key when pressing cmd
Actions["console_editor_switch"] = Action(167, PrimaryModifier, "Switch focus between editor and console")
