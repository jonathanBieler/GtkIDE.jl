"    SearchWindow <: GtkFrame
Search/replace panel that pops-up at the bottom of the editor.
It uses a global `GtkSourceSearchSettings` (search_settings) alongside
each `EditorTab` `GtkSourceSearchContext` (search_context).
Each tab also store the position of the current match using `GtkTextMark`'s.
"
type SearchWindow <: GtkFrame

    handle::Ptr{Gtk.GObject}
    search_entry::GtkEntry
    replace_entry::GtkEntry
    search_button::GtkButton
    replace_button::GtkButton
    replace_all_button::GtkButton
    search_settings::GtkSourceSearchSettings
    editor#not defined at this point

    function SearchWindow(editor)

        search_window = GtkFrame("") |>
            (GtkBox(:v) |>
                ((GtkBox(:h)) |>
                    (search_entry  = GtkEntry()) |>
                    (search_button = GtkButton("Search")) |>
                    (case_button = GtkToggleButton("Aa")) |>
                    (word_button = GtkToggleButton("Word"))
                ) |>
                ((GtkBox(:h)) |>
                    (replace_entry  = GtkEntry()) |>
                    (replace_button = GtkButton("Replace")) |>
                    (replace_all_button = GtkButton("Replace All"))
                )
            )

        setproperty!(search_window,:height_request, 70)
        setproperty!(search_entry,:hexpand,true)
        setproperty!(replace_entry,:hexpand,true)

        search_settings = GtkSourceSearchSettings()
        setproperty!(search_settings,:wrap_around,true)

        w = new(search_window.handle,
        search_entry, replace_entry,
        search_button,replace_button,replace_all_button,
        search_settings,editor)

        Gtk.gobject_move_ref(w, search_window)

        signal_connect(case_button_toggled_cb, case_button, "toggled", Void, (), false, w)
        signal_connect(word_button_toggled_cb, word_button, "toggled", Void, (), false, w)

        w
    end
end

import Base.open
function open(w::SearchWindow)
    visible(w,true)
    grab_focus(w.search_entry)
    showall(w)
end

#first define the callbacks that are used in the constructor
function case_button_toggled_cb(widgetptr::Ptr, user_data)
#    tb = convert(GtkToggleButton, widgetptr)
    search_window = user_data
    iscase = getproperty(search_window.search_settings,:case_sensitive,Bool)
    setproperty!(search_window.search_settings,:case_sensitive,!iscase)
    return nothing
end
function word_button_toggled_cb(widgetptr::Ptr, user_data)
#    tb = convert(GtkToggleButton, widgetptr)
    search_window = user_data
    isword = getproperty(search_window.search_settings,:at_word_boundaries,Bool)
    setproperty!(search_window.search_settings,:at_word_boundaries,!isword)
    return nothing
end

import GtkSourceWidget.get_search_text
get_search_text(s::GtkSourceSearchSettings) = getproperty(s,:search_text,AbstractString)

function search_entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)

    widget = convert(GtkEntry, widgetptr)
    event = unsafe_load(eventptr)
    search_window = user_data

    if event.keyval == Gtk.GdkKeySyms.Escape
        set_search_text(search_window.search_settings, "")
        visible(search_window,false)
    end

    if event.keyval == Gtk.GdkKeySyms.Return
        t = current_tab(search_window.editor)
        search_forward(t)
    end

    return convert(Cint,false)
end

function search_forward(t::EditorTab)

    if t.search_mark_end == nothing
        t.search_mark_end = text_buffer_create_mark(t.buffer,Gtk.GtkTextIter(t.buffer,1))#search from the start
    end

    it = text_buffer_get_iter_at_mark(t.buffer,t.search_mark_end)
    it = nonmutable(t.buffer,it)
    (found,its,ite) = search_context_forward(t.search_context,it)

    if found
        scroll_to_iter(t.view,its)
        t.search_mark_start  = text_buffer_create_mark(t.buffer,its)#save the position for next search
        t.search_mark_end  = text_buffer_create_mark(t.buffer,ite)
    end
    return found
end

function search_entry_key_release_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkEntry, widgetptr)
    search_window = user_data

    s = getproperty(widget,:text,AbstractString)
    set_search_text(search_window.search_settings,s)

    return convert(Cint,false)
end

@guarded (INTERRUPT)  function replace_entry_key_press_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    entry = convert(GtkEntry, widgetptr)
    event = unsafe_load(eventptr)
    search_window = user_data

    if event.keyval == Gtk.GdkKeySyms.Escape
        set_search_text(search_window.search_settings,"")
        visible(search_window,false)
    end

    if event.keyval == Gtk.GdkKeySyms.Return
        t = current_tab(search_window.editor)
        replace_forward(t,entry,search_window)
    end

    return PROPAGATE
end

function replace_forward(t::EditorTab,entry::GtkEntry,search_window::SearchWindow)

    search_text = get_search_text(search_window.search_settings)

    do_search = false
    if t.search_mark_end != nothing && t.search_mark_start != nothing
        its = text_buffer_get_iter_at_mark(t.buffer,t.search_mark_start)
        ite = text_buffer_get_iter_at_mark(t.buffer,t.search_mark_end)

        #if it doesn't match, we search forward
        if text_iter_get_text(its,ite)!= search_text
            do_search = true
        end
    else
        do_search = true
    end

    if do_search
        !search_forward(t) && return INTERRUPT
        its = text_buffer_get_iter_at_mark(t.buffer,t.search_mark_start)
        ite = text_buffer_get_iter_at_mark(t.buffer,t.search_mark_end)
    end

    s = getproperty(entry,:text,AbstractString)
    search_context_replace(t.search_context,its,ite,s)
end

function replace_all(t::EditorTab,entry::GtkEntry,search_window::SearchWindow)

    search_text = get_search_text(search_window.search_settings)
    search_text == "" && return

    s = getproperty(entry,:text,AbstractString)
    GtkSourceWidget.search_context_replace_all(t.search_context,s)
end

function search_button_clicked_cb(widgetptr::Ptr, user_data)
    search_window = user_data
    search_forward(current_tab(search_window.editor))
    return nothing
end

function replace_button_clicked_cb(widgetptr::Ptr, user_data)

    search_window = user_data
    t = current_tab(search_window.editor)
    replace_forward(t,search_window.replace_entry,search_window)
    return nothing
end

function init!(search_window::SearchWindow)

    signal_connect(search_entry_key_press_cb, search_window.search_entry, "key-press-event", Cint, (Ptr{Gtk.GdkEventKey},), false,search_window)
    signal_connect(search_entry_key_release_cb, search_window.search_entry, "key-release-event", Cint, (Ptr{Gtk.GdkEventKey},), false,search_window)
    signal_connect(replace_entry_key_press_cb, search_window.replace_entry, "key-press-event", Cint, (Ptr{Gtk.GdkEventKey},), false,search_window)
    signal_connect(search_button_clicked_cb, search_window.search_button, "clicked", Void, (), false,search_window)
    signal_connect(replace_button_clicked_cb, search_window.replace_button, "clicked", Void, (), false,search_window)
    signal_connect(search_window_quit_cb, search_window, "delete-event", Cint, (Ptr{Gtk.GdkEventKey},), false)
    signal_connect(replace_all_button_clicked_cb, search_window.replace_all_button, "clicked", Void, (), false,search_window)
end

function replace_all_button_clicked_cb(widgetptr::Ptr, user_data)
    search_window = user_data
    replace_all(current_tab(search_window.editor), search_window.replace_entry, search_window)
    return nothing
end

function search_window_quit_cb(widgetptr::Ptr,eventptr::Ptr, user_data)

    return convert(Cint,true)
end


##
