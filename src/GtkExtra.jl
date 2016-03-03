
GtkIconThemeGetDefault() =  ccall((:gtk_icon_theme_get_default,Gtk.libgtk),Ptr{GObject},())

GtkIconThemeAddResourcePath(iconTheme,path::AbstractString) =  ccall((:gtk_icon_theme_append_search_path,Gtk.libgtk),Void,(
 Ptr{GObject}, Ptr{UInt8}),iconTheme,path
);
function GtkIconThemeLoadIconForScale(iconTheme,icon_name::AbstractString, size::Integer, scale::Integer, flags::Integer)
  local pixbuf::Ptr{GObject}
   Gtk.GError() do error_check

    pixbuf = ccall((:gtk_icon_theme_load_icon_for_scale,Gtk.libgtk),
                   Ptr{GObject},
                   (Ptr{GObject},Ptr{UInt8},Cint,Cint,Cint,Ptr{Ptr{Gtk.GError}}),
                   iconTheme,bytestring(icon_name),size,scale,flags,error_check)

  return pixbuf !== C_NULL
  end
   return GdkPixbufLeaf(pixbuf)
end

Gtk.@Gtype GtkEntryBuffer Gtk.libgtk gtk_entry_buffer

function delete_text(entry::GtkEntryBuffer, position::Integer, n_chars::Integer)
        return ccall((:gtk_entry_buffer_delete_text,Gtk.libgtk),Ptr{Void},(Ptr{Gtk.GObject},Cuint,Cint),entry,position,n_chars)
end
function insert_text(entry::GtkEntryBuffer, position::Integer, data::AbstractString, n_chars::Integer)
  return ccall((:gtk_entry_buffer_insert_text,Gtk.libgtk),
               Ptr{Void},
              (Ptr{Gtk.GObject},Cuint,Cstring,Cint),
              entry,position,pointer(data),n_chars)
end
import Gtk
function buffer(entry::Gtk.GtkEntry)
       return convert(GtkEntryBuffer,ccall((:gtk_entry_get_buffer,Gtk.libgtk),Ptr{GtkEntryBuffer},(Ptr{Gtk.GObject},),entry))
end
