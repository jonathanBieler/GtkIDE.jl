module CairoExtensions

using Cairo
const libpango = Cairo._jl_libpango

export FontDescription, show, showall

type FontDescription
    ptr::Ptr{Void}

    FontDescription(ptr::Ptr{Void}) = new(ptr)
end

FontDescription() = FontDescription( ccall((:pango_font_description_new,libpango),Ptr{Void},()) )
FontDescription(str::AbstractString) = FontDescription( font_description_from_string(str) )

import Base: show, showall
show(io::IO,ft::FontDescription) = println(io,font_description_to_string(ft.ptr))
showall(io::IO,ft::FontDescription) = println(io,font_description_to_string(ft.ptr))

font_description_set_family(font_description::Ptr{Void},family::AbstractString) = ccall((:pango_font_description_set_family,libpango),Void,
(Ptr{Void},Ptr{UInt8}),font_description,family)

font_description_from_string(str::AbstractString) = ccall((:pango_font_description_from_string,libpango),Ptr{Void},
(Ptr{UInt8},),str)

font_description_to_string(font_description::Ptr{Void}) = bytestring(ccall((:pango_font_description_to_string,libpango),Ptr{UInt8},
(Ptr{Void},),font_description))

# ft = FontDescription()
# ft = FontDescription("monospace 12")
#
# font_description_set_family(ft.ptr,"monospace")
# font_description_to_string(ft.ptr)

# fontmap = pango_cairo_font_map_get_default();
#     pango_font_map_list_families (fontmap, & families, & n_families);
#     printf ("There are %d families\n", n_families);
#     for (i = 0; i < n_families; i++) {
#         PangoFontFamily * family = families[i];
#         const char * family_name;
#
#         family_name = pango_font_family_get_name (family);
#         printf ("Family %d: %s\n", i, family_name);
#     }

end
