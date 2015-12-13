
type SearchWindow <: GtkFrame

    handle::Ptr{Gtk.GObject}
    entry::GtkEntry
    function SearchWindow()

        global search_window = @GtkFrame("Search") |>
            (search_entry = @GtkEntry())

        setproperty!(search_window,:height_request, 120)

        w = new(search_window.handle,search_entry)
        Gtk.gobject_move_ref(w, search_window)
    end
end

global search_window = SearchWindow()

import Base.open
function open(w::SearchWindow)
    visible(w,true)
    grab_focus(w.entry)
    showall(w)
end

function search_entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    event = convert(Gtk.GdkEvent, eventptr)

    if event.keyval == Gtk.GdkKeySyms.Escape
        set_search_text("")
        visible(search_window,false)
    end

    if event.keyval == Gtk.GdkKeySyms.Return

        t = get_current_tab()
        if t.search_mark == nothing
            t.search_mark = text_buffer_create_mark(t.buffer,Gtk.GtkTextIter(t.buffer,1))#search from the start
        end

        it = text_buffer_get_iter_at_mark(t.buffer,t.search_mark)
        it = Gtk.GtkTextIter(t.buffer, getproperty(it,:offset,Int)+1)#FIXME need unmutable here?
        (found,its,ite) = search_context_forward(t.search_context,it)

        if found
            scroll_to_iter(t.view,its)
            t.search_mark  = text_buffer_create_mark(t.buffer,ite)#save the position for next search
        end

    end

    return convert(Cint,false)
end

function search_entry_key_release_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)

    s = getproperty(widget,:text,AbstractString)
    set_search_text(s)

    return convert(Cint,false)
end

signal_connect(search_entry_key_press_cb, search_window.entry, "key-press-event", Cint, (Ptr{Gtk.GdkEvent},), false)
signal_connect(search_entry_key_release_cb, search_window.entry, "key-release-event", Cint, (Ptr{Gtk.GdkEvent},), false)

visible(search_window,false)

##

#global search_window = @GtkWindow("search",200,50) |>
#    (search_entry = @GtkEntry())
#visible(search_window,false)
#Gtk.G_.keep_above(search_window,true)

##
function search_window_quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    #@show "wesh"
    return convert(Cint,true)
end
signal_connect(search_window_quit_cb, search_window, "delete-event", Cint, (Ptr{Gtk.GdkEvent},), false)

##
