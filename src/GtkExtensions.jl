# module GtkExtenstions
#
# export text_iter_get_text, text_iter_forward_line, text_iter_backward_line, text_iter_forward_to_line_end, text_iter_forward_word_end,
# 	   text_iter_backward_word_start, text_iter_forward_search, text_iter_backward_search, show_iter,
# 	   text_buffer_place_cursor, get_iter_at_position, text_view_window_to_buffer_coords, get_current_page_idx,
# 	   set_current_page_idx, get_tab, set_position!, text_buffer_copy_clipboard, set_tab_label_text
#
# using Gtk

import ..Gtk: suffix
import Gtk.GtkTextIter, Gtk.libgtk

const PROPAGATE = convert(Cint,false)
const INTERRUPT = convert(Cint,true)

import Gtk.GConstants: GdkModifierType
import Gtk.GdkKeySyms

get_default_mod_mask() = ccall((:gtk_accelerator_get_default_mod_mask , libgtk),
    typeof(GdkModifierType.CONTROL),()
)

## Widget

grab_focus(w::Gtk.GObject) = ccall((:gtk_widget_grab_focus , libgtk),Void,(Ptr{Gtk.GObject},),w)#this should work?
grab_focus(w::Gtk.GtkWindow) = ccall((:gtk_widget_grab_focus , libgtk),Void,(Ptr{Gtk.GObject},),w)

## TextIters

typealias MutableGtkTextIter Gtk.GLib.MutableTypes.Mutable{GtkTextIter}
typealias GtkTextIters Union{MutableGtkTextIter,GtkTextIter}
mutable(it::GtkTextIter) = Gtk.GLib.MutableTypes.mutable(it)

offset(it::GtkTextIters) = getproperty(it,:offset,Integer)
line(it::GtkTextIters) = getproperty(it,:line,Integer)+1#Gtk counts from zero
nonmutable(buffer::GtkTextBuffer,it::MutableGtkTextIter) = GtkTextIter(buffer,offset(it)+1)#this allows to convert to GtkTextBuffer without the -1 definition in Gtk.jl

getbuffer(it::GtkTextIter) = convert(GtkTextBuffer,
    ccall((:gtk_text_iter_get_buffer, libgtk),Ptr{GtkTextBuffer},(Ref{GtkTextIter},),it)
)
getbuffer(it::MutableGtkTextIter) = convert(GtkTextBuffer,
    ccall((:gtk_text_iter_get_buffer, libgtk),Ptr{GtkTextBuffer},(Ptr{GtkTextIter},),it)
)

import Base.show
show(io::IO, it::GtkTextIter) = println("GtkTextIter($(offset(it)))")

function text_iter_get_text(it_start::MutableGtkTextIter,it_end::MutableGtkTextIter)
	s = ccall((:gtk_text_iter_get_text,libgtk),Ptr{UInt8},(Ptr{GtkTextIter},Ptr{GtkTextIter}),it_start,it_end)
    return s == C_NULL ? "" : bytestring(s)
end
function text_iter_get_text(it_start::GtkTextIter,it_end::GtkTextIter)
	s = ccall((:gtk_text_iter_get_text,libgtk),Ptr{UInt8},(Ref{GtkTextIter},Ref{GtkTextIter}),it_start,it_end)
    return s == C_NULL ? "" : bytestring(s)
end

text_iter_forward_line(it::MutableGtkTextIter)  = ccall((:gtk_text_iter_forward_line,  libgtk),Cint,(Ptr{GtkTextIter},),it)
text_iter_backward_line(it::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_line, libgtk),Cint,(Ptr{GtkTextIter},),it)
text_iter_forward_to_line_end(it::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_to_line_end, libgtk),Cint,(Ptr{GtkTextIter},),it)

text_iter_forward_word_end(it::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_word_end, libgtk),Cint,(Ptr{GtkTextIter},),it)
text_iter_backward_word_start(it::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_word_start, libgtk),Cint,(Ptr{GtkTextIter},),it)

text_iter_backward_sentence_start(it::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_sentence_start, libgtk),Cint,(Ptr{GtkTextIter},),it)
text_iter_forward_sentence_end(it::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_sentence_end, libgtk),Cint,(Ptr{GtkTextIter},),it)


text_iter_forward_search(it::MutableGtkTextIter, txt::AbstractString, start::MutableGtkTextIter, stop::MutableGtkTextIter, limit::MutableGtkTextIter) = ccall((:gtk_text_iter_forward_search, libgtk),
  Cint,
  (Ptr{GtkTextIter},Ptr{UInt8},Cint,Ptr{GtkTextIter},Ptr{GtkTextIter},Ptr{GtkTextIter}),
  it,bytestring(txt),Int32(2),start,stop,limit
)
function text_iter_forward_search(buffer::GtkTextBuffer, txt::AbstractString)
  its = mutable(GtkTextIter(buffer))
  ite = mutable(GtkTextIter(buffer))
  found = text_iter_forward_search(mutable( GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))),txt,its,ite,mutable(GtkTextIter(buffer,length(buffer)+1)))

  return (found==1,its,ite)
end

text_iter_backward_search(it::MutableGtkTextIter, txt::AbstractString, start::MutableGtkTextIter, stop::MutableGtkTextIter, limit::MutableGtkTextIter) = ccall((:gtk_text_iter_backward_search, libgtk),
  Cint,
  (Ptr{GtkTextIter},Ptr{UInt8},Cint,Ptr{GtkTextIter},Ptr{GtkTextIter},Ptr{GtkTextIter}),
  it,bytestring(txt),Int32(2),start,stop,limit
)
function text_iter_backward_search(buffer::GtkTextBuffer, txt::AbstractString)
  its = mutable(GtkTextIter(buffer))
  ite = mutable(GtkTextIter(buffer))
  found = text_iter_backward_search(mutable( GtkTextIter(buffer,getproperty(buffer,:cursor_position,Int))),txt,its,ite,mutable(GtkTextIter(buffer,1)))

  return (found==1,its,ite)
end

function show_iter(it::MutableGtkTextIter,buffer::GtkTextBuffer,color::Int)
    Gtk.apply_tag(buffer, color > 0 ? "debug1" : "debug2",it, it+1)
end

##
function selection_bounds(buffer::Gtk.GtkTextBuffer)
    its = mutable( GtkTextIter(buffer) )
    ite = mutable( GtkTextIter(buffer) )
    return (convert(Bool,ccall((:gtk_text_buffer_get_selection_bounds,libgtk),Cint,(Ptr{Gtk.GObject},
            Ptr{GtkTextIter},Ptr{GtkTextIter}),buffer,its,ite)),its,ite)
end
function selection_bounds(buffer::Gtk.GtkTextBuffer,ins::GtkTextIter,bound::GtkTextIter)
    ccall((:gtk_text_buffer_select_range,libgtk),Void,(Ptr{Gtk.GObject},Ref{GtkTextIter},Ref{GtkTextIter}),buffer,ins,bound)
end
function selection_bounds(buffer::Gtk.GtkTextBuffer,ins::MutableGtkTextIter,bound::MutableGtkTextIter)
    ccall((:gtk_text_buffer_select_range,libgtk),Void,(Ptr{Gtk.GObject},Ptr{GtkTextIter},Ptr{GtkTextIter}),buffer,ins,bound)
end
##
function end_iter(buffer::Gtk.GtkTextBuffer)
    iter = Gtk.mutable(GtkTextIter)
    ccall((:gtk_text_buffer_get_end_iter,libgtk),Void,(Ptr{Gtk.GObject},Ptr{GtkTextIter}),buffer,iter)
    return iter
end

text_buffer_place_cursor(buffer::GtkTextBuffer,it::GtkTextIter)  = ccall((:gtk_text_buffer_place_cursor,  libgtk),Void,(Ptr{Gtk.GObject},Ref{GtkTextIter}),buffer,it)
text_buffer_place_cursor(buffer::GtkTextBuffer,pos::Int) = text_buffer_place_cursor(buffer,GtkTextIter(buffer,pos+1))
text_buffer_place_cursor(buffer::GtkTextBuffer,it::MutableGtkTextIter) = text_buffer_place_cursor(buffer,nonmutable(buffer,it))

text_buffer_create_mark(buffer::GtkTextBuffer,mark_name,it::GtkTextIters,left_gravity::Bool)  = GtkTextMarkLeaf(ccall((:gtk_text_buffer_create_mark, libgtk),Ptr{GObject},
    (Ptr{Gtk.GObject},Ptr{UInt8},GtkTextIters,Cint),buffer,mark_name,it,left_gravity))

text_buffer_create_mark(buffer::GtkTextBuffer,it::GtkTextIters)  = text_buffer_create_mark(buffer,C_NULL,it,false)

function text_buffer_get_iter_at_mark(buffer::GtkTextBuffer,mark::GtkTextMark)
    iter = mutable(GtkTextIter())
    ccall((:gtk_text_buffer_get_iter_at_mark,  libgtk),Void,(Ptr{Gtk.GObject},Ptr{MutableGtkTextIter},Ptr{Gtk.GObject}),buffer,iter,mark)
    return iter
end

line_count(buffer::GtkTextBuffer) = ccall((:gtk_text_buffer_get_line_count,libgtk),Cint,(Ptr{GObject},),buffer)

## TextView

get_iter_at_position(text_view::Gtk.GtkTextView,iter::MutableGtkTextIter,trailing,x::Int32,y::Int32) = ccall((:gtk_text_view_get_iter_at_position,libgtk),Void,
	(Ptr{Gtk.GObject},Ptr{GtkTextIter},Ptr{Cint},Cint,Cint),text_view,iter,trailing,x,y)

function get_iter_at_position(text_view::Gtk.GtkTextView,x::Integer,y::Integer)
    buffer = getproperty(text_view,:buffer,GtkTextBuffer)
    iter = mutable(GtkTextIter(buffer))
    get_iter_at_position(text_view::Gtk.GtkTextView,iter,C_NULL,Int32(x),Int32(y))
    return nonmutable(buffer,iter)
end

function text_view_window_to_buffer_coords(text_view::Gtk.GtkTextView,wintype::Integer,window_x::Integer,window_y::Integer)

	buffer_x = Gtk.mutable(Cint)
	buffer_y = Gtk.mutable(Cint)

	ccall((:gtk_text_view_window_to_buffer_coords,libgtk),Void,
		(Ptr{Gtk.GObject},Cint,Cint,Cint,Ptr{Cint},Ptr{Cint}),text_view,Int32(wintype),window_x,window_y,buffer_x,buffer_y)

	return (buffer_x[],buffer_y[])
end
text_view_window_to_buffer_coords(text_view::Gtk.GtkTextView,window_x::Integer,window_y::Integer) = text_view_window_to_buffer_coords(text_view,2,window_x,window_y)

function text_view_buffer_to_window_coords(text_view::Gtk.GtkTextView,wintype::Integer,buffer_x::Integer,buffer_y::Integer)

	window_x = Gtk.mutable(Cint)
	window_y = Gtk.mutable(Cint)

	ccall((:gtk_text_view_buffer_to_window_coords,libgtk),Void,
		(Ptr{Gtk.GObject},Cint,Cint,Cint,Ptr{Cint},Ptr{Cint}),text_view,Int32(wintype),buffer_x,buffer_y,window_x,window_y)

	return (window_x[],window_y[])
end
text_view_buffer_to_window_coords(text_view::Gtk.GtkTextView,buffer_x::Integer,buffer_y::Integer) = text_view_window_to_buffer_coords(text_view,0,buffer_x,buffer_y)

function cursor_locations(text_view::Gtk.GtkTextView)
    weak = Gtk.mutable(Gtk.GdkRectangle)
    strong = Gtk.mutable(Gtk.GdkRectangle)
    buffer = getproperty(text_view,:buffer,GtkTextBuffer)
    iter = mutable( GtkTextIter(buffer, getproperty(buffer,:cursor_position,Int)) )

    ccall((:gtk_text_view_get_cursor_locations,libgtk),Void,(Ptr{Gtk.GObject},Ptr{GtkTextIter},Ptr{Gtk.GdkRectangle},Ptr{Gtk.GdkRectangle}),text_view,iter,strong,weak)
    return (iter,strong[],weak[])
end

scroll_to_iter(text_view::Gtk.GtkTextView,iter::GtkTextIter,within_margin::Number,use_align::Bool,xalign::Number,yalign::Number) = ccall((:gtk_text_view_scroll_to_iter,libgtk),Cint,
	(Ptr{Gtk.GObject},Ref{GtkTextIter},Cdouble,Cint,Cdouble,Cdouble),
    text_view,iter,within_margin,use_align,xalign,yalign)

scroll_to_iter(text_view::Gtk.GtkTextView,iter::MutableGtkTextIter,within_margin::Number,use_align::Bool,xalign::Number,yalign::Number) = ccall((:gtk_text_view_scroll_to_iter,libgtk),Cint,
	(Ptr{Gtk.GObject},Ptr{GtkTextIter},Cdouble,Cint,Cdouble,Cdouble),
    text_view,iter,within_margin,use_align,xalign,yalign)

scroll_to_iter(text_view::Gtk.GtkTextView,iter::GtkTextIters) = scroll_to_iter(text_view,iter,0.0,true,1.0,0.1)

# notebook
get_current_page_idx(notebook::Gtk.GtkNotebook) = ccall((:gtk_notebook_get_current_page,libgtk),Cint,
    (Ptr{Gtk.GObject},),notebook)+1 #+1 so it works with splice!

set_current_page_idx(notebook::Gtk.GtkNotebook,page_num::Int) = ccall((:gtk_notebook_set_current_page,libgtk),Void,
    (Ptr{Gtk.GObject},Cint),notebook,page_num-1)

get_tab(notebook::Gtk.GtkNotebook,page_num::Int) = convert(Gtk.GtkWidget,ccall((:gtk_notebook_get_nth_page,libgtk),Ptr{Gtk.GObject},
	(Ptr{Gtk.GObject},Cint),notebook,page_num-1))

set_tab_label_text(notebook::Gtk.GtkNotebook,child,tab_text) = ccall((:gtk_notebook_set_tab_label_text,Gtk.libgtk),Void,(Ptr{Gtk.GObject},
Ptr{Gtk.GObject},Ptr{UInt8}),notebook,child,tab_text)

## entry

function set_position!(editable::Gtk.Entry,position_)
    ccall((:gtk_editable_set_position,libgtk),Void,(Ptr{Gtk.GObject},Cint),editable,position_)
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

GtkClipboardLeaf(selection::UInt16) =  GtkClipboardLeaf(ccall((:gtk_clipboard_get,libgtk), Ptr{GObject},
    (UInt16,), selection))
GtkClipboardLeaf() = GtkClipboardLeaf(GdkAtoms.SELECTION_CLIPBOARD)
clipboard_set_text(clip::GtkClipboard,text::AbstractString) = ccall((:gtk_clipboard_set_text,libgtk), Void,
    (Ptr{GObject}, Ptr{UInt8},Cint), clip, text, sizeof(text))
clipboard_store(clip::GtkClipboard) = ccall((:gtk_clipboard_store,libgtk), Void,
    (Ptr{GObject},), clip)

#note: this needs main_loops to run
function clipboard_wait_for_text(clip::GtkClipboard)
    ptr = ccall((:gtk_clipboard_wait_for_text,libgtk), Ptr{UInt8},
        (Ptr{GObject},), clip)
    return ptr == C_NULL ? "" : bytestring(ptr)
end

text_buffer_copy_clipboard(buffer::GtkTextBuffer,clip::GtkClipboard)  = ccall((:gtk_text_buffer_copy_clipboard, libgtk),Void,
    (Ptr{GObject},Ptr{GObject}),buffer,clip)


##
function GtkCssProviderFromData(;data=nothing,filename=nothing)
    source_count = (data!==nothing) + (filename!==nothing)
    @assert(source_count <= 1,
        "GtkCssProvider must have at most one data or filename argument")
    provider = GtkCssProviderLeaf(ccall((:gtk_css_provider_get_default,libgtk),Ptr{Gtk.GObject},()))
    if data !== nothing
        Gtk.GError() do error_check
          ccall((:gtk_css_provider_load_from_data,libgtk), Bool,
            (Ptr{Gtk.GObject}, Ptr{UInt8}, Clong, Ptr{Ptr{Gtk.GError}}),
            provider, bytestring(data), sizeof(data), error_check)
        end
    elseif filename !== nothing
        Gtk.GError() do error_check
          ccall((:gtk_css_provider_load_from_path,libgtk), Bool,
            (Ptr{Gtk.GObject}, Ptr{UInt8}, Clong, Ptr{Ptr{Gtk.GError}}),
            provider, bytestring(filename), error_check)
        end
    end
    return provider
end

## Gdk

function gdk_window_get_origin(window)

	window_x = Gtk.mutable(Cint)
	window_y = Gtk.mutable(Cint)

	ccall((:gdk_window_get_origin,Gtk.libgdk),Cint,
		(Ptr{Gtk.GObject},Ptr{Cint},Ptr{Cint}),window,window_x,window_y)

	return (window_x[],window_y[])
end

gdk_keyval_name(val) = bytestring(
    ccall((:gdk_keyval_name,libgtk),Ptr{UInt8},(Cuint,),val),
true)

## GLib


function g_timeout_add(interval::Integer,cb,user_data) 

    callback = cfunction(cb,Cint,(Ptr{Void},))
    
    ref, deref = Gtk.GLib.gc_ref_closure(user_data)#not sure about that
    interval = UInt32(interval)

    return ccall((:g_timeout_add, Gtk.GLib.libglib),Cint,
        (UInt32, Ptr{Void}, Ptr{Void}),
         interval, callback, ref)
end

function g_idle_add(cb,user_data) 

    callback = cfunction(cb,Cint,(Ptr{Void},))
    
    ref, deref = Gtk.GLib.gc_ref_closure(user_data)#not sure about that

    return ccall((:g_idle_add, Gtk.GLib.libglib),Cint,
        (Ptr{Void}, Ptr{Void}),
         callback, ref)
end





#end#module
