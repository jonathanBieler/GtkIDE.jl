# module GtkExtenstions
#
# export text_iter_get_text, text_iter_forward_line, text_iter_backward_line, text_iter_forward_to_line_end, text_iter_forward_word_end,
# 	   text_iter_backward_word_start, text_iter_forward_search, text_iter_backward_search, show_iter,
# 	   text_buffer_place_cursor, get_iter_at_position, text_view_window_to_buffer_coords, get_current_page_idx,
# 	   set_current_page_idx, get_tab, set_position!, text_buffer_copy_clipboard, set_tab_label_text
#
# using Gtk
# const libgtk = Gtk.Gtk.libgtk

import ..Gtk: suffix

## Widget

grab_focus(w::Gtk.GObject) = ccall((:gtk_widget_grab_focus , Gtk.libgtk),Void,(Ptr{Gtk.GObject},),w)#this should work?
grab_focus(w::Gtk.GtkWindow) = ccall((:gtk_widget_grab_focus , Gtk.libgtk),Void,(Ptr{Gtk.GObject},),w)

##
baremodule GdkModifierType
    const SHIFT		= Main.Base.convert(Int32,1)
    const LOCK 	  	= Main.Base.convert(Int32,2)
	const CONTROL 	= Main.Base.convert(Int32,4)
end

typealias MutableGtkTextIter Gtk.GLib.MutableTypes.Mutable{Gtk.GtkTextIter}
typealias GtkTextIters Union{MutableGtkTextIter,Gtk.GtkTextIter}
mutable(it::Gtk.GtkTextIter) = Gtk.GLib.MutableTypes.mutable(it)

function text_iter_get_text(it_start::GtkTextIters,it_end::GtkTextIters)
	s = ccall((:gtk_text_iter_get_text,Gtk.libgtk),Ptr{Uint8},(Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}),it_start,it_end)
	return s == C_NULL ? "" : bytestring(s)
end

text_iter_forward_line(it::MutableGtkTextIter)  = ccall((:gtk_text_iter_forward_line,  Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_backward_line(it::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_line, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_forward_to_line_end(it::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_to_line_end, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)

text_iter_forward_word_end(it::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_word_end, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)
text_iter_backward_word_start(it::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_word_start, Gtk.libgtk),Cint,(Ptr{Gtk.GtkTextIter},),it)

text_iter_forward_search(it::MutableGtkTextIter, txt::String, start::MutableGtkTextIter, stop::MutableGtkTextIter, limit::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_search, Gtk.libgtk),
  Cint,
  (Ptr{Gtk.GtkTextIter},Ptr{Uint8},Cint,Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}),
  it,bytestring(txt),Int32(2),start,stop,limit
)
function text_iter_forward_search(buffer::GtkTextBuffer, txt::String)
  its = mutable(Gtk.GtkTextIter(buffer))
  ite = mutable(Gtk.GtkTextIter(buffer))
  found = text_iter_forward_search(mutable( Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))),txt,its,ite,mutable(Gtk.GtkTextIter(buffer,length(buffer))))

  return (found,its,ite)
end

text_iter_backward_search(it::MutableGtkTextIter, txt::String, start::MutableGtkTextIter, stop::MutableGtkTextIter, limit::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_search, Gtk.libgtk),
  Cint,
  (Ptr{Gtk.GtkTextIter},Ptr{Uint8},Cint,Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}),
  it,bytestring(txt),Int32(2),start,stop,limit
)
function text_iter_backward_search(buffer::GtkTextBuffer, txt::String)
  its = mutable(Gtk.GtkTextIter(buffer))
  ite = mutable(Gtk.GtkTextIter(buffer))
  found = text_iter_backward_search(mutable( Gtk.GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))),txt,its,ite,mutable(Gtk.GtkTextIter(buffer,1)))

  return (found,its,ite)
end

function show_iter(it::MutableGtkTextIter,buffer::GtkTextBuffer,color::Int)
    Gtk.apply_tag(buffer, color > 0 ? "debug1" : "debug2",it, it+1)
end

function selection_bounds(buffer::Gtk.GtkTextBuffer)
    its = mutable(Gtk.GtkTextIter(buffer))
    ite = mutable(Gtk.GtkTextIter(buffer))
    return (convert(Bool,ccall((:gtk_text_buffer_get_selection_bounds,Gtk.libgtk),Cint,(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}),buffer,its,ite)),its,ite)
end

function end_iter(buffer::Gtk.GtkTextBuffer)
    iter = Gtk.mutable(Gtk.GtkTextIter)
    ccall((:gtk_text_buffer_get_end_iter,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter}),buffer,iter)
    return iter
end

text_buffer_place_cursor(buffer::GtkTextBuffer,it::MutableGtkTextIter)  = ccall((:gtk_text_buffer_place_cursor,  Gtk.libgtk),Void,(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter}),buffer,it)
text_buffer_place_cursor(buffer::GtkTextBuffer,pos::Int) = text_buffer_place_cursor(srcbuffer,mutable(Gtk.GtkTextIter(srcbuffer,pos)))
text_buffer_place_cursor(buffer::GtkTextBuffer,it::Gtk.GtkTextIter) = text_buffer_place_cursor(srcbuffer,mutable(it))

text_buffer_create_mark(buffer::GtkTextBuffer,mark_name,it::GtkTextIters,left_gravity::Bool)  = GtkTextMarkLeaf(ccall((:gtk_text_buffer_create_mark, Gtk.libgtk),Ptr{GObject},
    (Ptr{Gtk.GObject},Ptr{UInt8},GtkTextIters,Cint),buffer,mark_name,it,left_gravity))

text_buffer_create_mark(buffer::GtkTextBuffer,it::GtkTextIters)  = text_buffer_create_mark(buffer,C_NULL,it,false)

function text_buffer_get_iter_at_mark(buffer::GtkTextBuffer,mark::GtkTextMark)
    iter = mutable(Gtk.GtkTextIter())
    ccall((:gtk_text_buffer_get_iter_at_mark,  Gtk.libgtk),Void,(Ptr{Gtk.GObject},Ptr{MutableGtkTextIter},Ptr{Gtk.GObject}),buffer,iter,mark)
    return iter
end

text_buffer_delete(buffer::GtkTextBuffer,itstart::GtkTextIters,itend::GtkTextIters)  = ccall((:gtk_text_buffer_delete,  Gtk.libgtk),Void,
(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter},Ptr{Gtk.GtkTextIter}),buffer,itstart,itend)

## TextView

get_iter_at_position(text_view::Gtk.GtkTextView,iter::MutableGtkTextIter,trailing,x::Int32,y::Int32) = ccall((:gtk_text_view_get_iter_at_position,Gtk.libgtk),Void,
	(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter},Ptr{Cint},Cint,Cint),text_view,iter,trailing,x,y)

function get_iter_at_position(text_view::Gtk.GtkTextView,x::Integer,y::Integer)
	 iter = mutable(Gtk.GtkTextIter(getproperty(text_view,:buffer,GtkTextBuffer)))
	 get_iter_at_position(text_view::Gtk.GtkTextView,iter,C_NULL,Int32(x),Int32(y))
	 return iter
end

function text_view_window_to_buffer_coords(text_view::Gtk.GtkTextView,wintype::Int,window_x::Int,window_y::Int)

	buffer_x = Gtk.mutable(Cint)
	buffer_y = Gtk.mutable(Cint)

	ccall((:gtk_text_view_window_to_buffer_coords,Gtk.libgtk),Void,
		(Ptr{Gtk.GObject},Cint,Cint,Cint,Ptr{Cint},Ptr{Cint}),text_view,Int32(wintype),window_x,window_y,buffer_x,buffer_y)

	return (buffer_x[],buffer_y[])
end

text_view_window_to_buffer_coords(text_view::Gtk.GtkTextView,window_x::Int,window_y::Int) = text_view_window_to_buffer_coords(text_view,2,window_x,window_y)

scroll_to_iter(text_view::Gtk.GtkTextView,iter::GtkTextIters,within_margin::Number,use_align::Bool,xalign::Number,yalign::Number) = ccall((:gtk_text_view_scroll_to_iter,Gtk.libgtk),Cint,
	(Ptr{Gtk.GObject},Ptr{Gtk.GtkTextIter},Cdouble,Cint,Cdouble,Cdouble),
    text_view,iter,within_margin,use_align,xalign,yalign)

scroll_to_iter(text_view::Gtk.GtkTextView,iter::GtkTextIters) = scroll_to_iter(text_view,iter,0.0,true,1.0,0.1)

# notebook
get_current_page_idx(notebook::Gtk.GtkNotebook) = ccall((:gtk_notebook_get_current_page,Gtk.libgtk),Cint,
    (Ptr{Gtk.GObject},),notebook)+1 #+1 so it works with splice!

set_current_page_idx(notebook::Gtk.GtkNotebook,page_num::Int) = ccall((:gtk_notebook_set_current_page,Gtk.libgtk),Void,
    (Ptr{Gtk.GObject},Cint),notebook,page_num-1)

get_tab(notebook::Gtk.GtkNotebook,page_num::Int) = convert(Gtk.GtkWidget,ccall((:gtk_notebook_get_nth_page,Gtk.libgtk),Ptr{Gtk.GObject},
	(Ptr{Gtk.GObject},Cint),notebook,page_num-1))

set_tab_label_text(notebook::Gtk.GtkNotebook,child,tab_text) = ccall((:gtk_notebook_set_tab_label_text,Gtk.Gtk.libgtk),Void,(Ptr{Gtk.GObject},
Ptr{Gtk.GObject},Ptr{Uint8}),notebook,child,tab_text)

## entry

function set_position!(editable::Gtk.Entry,position_)
    ccall((:gtk_editable_set_position,Gtk.libgtk),Void,(Ptr{Gtk.GObject},Cint),editable,position_)
end

#####  GtkClipboard #####

Gtk.@gtktype GtkClipboard

baremodule GdkAtoms
    const NONE = 0x0000
    const SELECTION_PRIMARY = 0x0001
    const SELECTION_SECONDARY = 0x0002
    const SELECTION_TYPE_ATOM = 0x0004
    const SELECTION_TYPE_BITMAP = 0x0005
    const SELECTION_TYPE_COLORMAP = 0x0007
    const SELECTION_TYPE_DRAWABLE = 0x0011
    const SELECTION_TYPE_INTEGER = 0x0013
    const SELECTION_TYPE_PIXMAP = 0x0014
    const SELECTION_TYPE_STRING = 0x001f
    const SELECTION_TYPE_WINDOW = 0x0021
    const SELECTION_CLIPBOARD = 0x0045
end

GtkClipboardLeaf(selection::Uint16) =  GtkClipboardLeaf(ccall((:gtk_clipboard_get,Gtk.libgtk), Ptr{GObject},
    (Uint16,), selection))
GtkClipboardLeaf() = GtkClipboardLeaf(GdkAtoms.SELECTION_CLIPBOARD)
clipboard_set_text(clip::GtkClipboard,text::String) = ccall((:gtk_clipboard_set_text,Gtk.libgtk), Void,
    (Ptr{GObject}, Ptr{Uint8},Cint), clip, text, sizeof(text))
clipboard_store(clip::GtkClipboard) = ccall((:gtk_clipboard_store,Gtk.libgtk), Void,
    (Ptr{GObject},), clip)

#note: this needs main_loops to run
function clipboard_wait_for_text(clip::GtkClipboard)
    ptr = ccall((:gtk_clipboard_wait_for_text,Gtk.libgtk), Ptr{Uint8},
        (Ptr{GObject},), clip)
    return ptr == C_NULL ? "" : bytestring(ptr)
end

text_buffer_copy_clipboard(buffer::GtkTextBuffer,clip::GtkClipboard)  = ccall((:gtk_text_buffer_copy_clipboard, Gtk.libgtk),Void,
    (Ptr{GObject},Ptr{GObject}),buffer,clip)


##
function GtkCssProviderFromData(;data=nothing,filename=nothing)
    source_count = (data!==nothing) + (filename!==nothing)
    @assert(source_count <= 1,
        "GtkCssProvider must have at most one data or filename argument")
    provider = GtkCssProviderLeaf(ccall((:gtk_css_provider_get_default,Gtk.libgtk),Ptr{Gtk.GObject},()))
    if data !== nothing
        Gtk.GError() do error_check
          ccall((:gtk_css_provider_load_from_data,Gtk.libgtk), Bool,
            (Ptr{Gtk.GObject}, Ptr{UInt8}, Clong, Ptr{Ptr{Gtk.GError}}),
            provider, bytestring(data), sizeof(data), error_check)
        end
    elseif filename !== nothing
        Gtk.GError() do error_check
          ccall((:gtk_css_provider_load_from_path,Gtk.libgtk), Bool,
            (Ptr{Gtk.GObject}, Ptr{UInt8}, Clong, Ptr{Ptr{Gtk.GError}}),
            provider, bytestring(filename), error_check)
        end
    end
    return provider
end

#end#module
