mutable struct StyleAndLanguageManager
    languageDefinitions::Dict{AbstractString, GtkSourceWidget.GtkSourceLanguage}
    main_style::GtkSourceWidget.GtkSourceStyleScheme
    fontsize::Int
    fontCss::String
    style_provider::GtkCssProvider
    styles::Dict{String, GtkSourceWidget.GtkSourceStyle}

    function StyleAndLanguageManager()

        #FIXME this should be in GtkSourceWidget
        sourceStyleManager = GtkSourceStyleSchemeManager()
        GtkSourceWidget.set_search_path(sourceStyleManager,
          Any[joinpath(pkgdir(GtkSourceWidget), "share/gtksourceview-3.0/styles/"), C_NULL])

        languageDefinitions = Dict{AbstractString, GtkSourceWidget.GtkSourceLanguage}()
        sourceLanguageManager = GtkSourceWidget.sourceLanguageManager

        languageDefinitions[".jl"] = GtkSourceWidget.language(sourceLanguageManager, "julia")
        languageDefinitions[".md"] = GtkSourceWidget.language(sourceLanguageManager, "markdown")

        if Sys.iswindows()
            main_style = style_scheme(sourceStyleManager, "visualcode")
            fontsize = opt("fontsize")
            fontCss =  """button, entry, window, sourceview, textview  {
                font-family: Consolas, Courier, monospace;
                font-size: $(fontsize)px;
            }"""
        end
        if Sys.isapple()
            main_style = style_scheme(sourceStyleManager, "visualcode")
            fontsize = opt("fontsize")
            fontCss =  "button, entry, window, sourceview, textview {
                font-family: Monaco, Consolas, Courier, monospace;
                font-size: $(fontsize)px;
            }"
        end

        if Sys.islinux()
            main_style = style_scheme(sourceStyleManager, "visualcode")
            fontsize = opt("fontsize")-1
            fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
                font-family: Consolas, Courier, monospace;
                font-size: $(fontsize)px;
            }"""
        end

        provider = GtkExtensions.default_css_provider
        provider = GtkCssProviderFromData!(provider, data=fontCss)
        GtkIconThemeAddResourcePath(GtkIconThemeGetDefault(), joinpath(HOMEDIR, "../icons/"))

        # I'm getting duplicated GObject when calling style several times, 
        # so let's call it only once.
        styles = Dict(
            "text" => GtkSourceWidget.style(main_style, "text"),
            "def:note" => GtkSourceWidget.style(main_style, "def:note")
        )

        new(
            languageDefinitions,
            main_style,
            fontsize,
            fontCss,
            provider,
            styles
        )
    end
end

get_style(mng::StyleAndLanguageManager, style_id::String) =
    haskey(mng.styles, style_id) ? mng.styles[style_id] : GtkSourceWidget.style(mng.main_style, style_id) 