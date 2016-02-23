
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
