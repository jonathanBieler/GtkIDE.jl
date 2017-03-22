type StyleAndLanguageManager
    languageDefinitions::Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}
    main_style::GtkSourceWidget.GtkSourceStyleScheme
    fontsize
    fontCss
    style_provider

    function StyleAndLanguageManager()

        #FIXME this should be in GtkSourceWidget
        sourceStyleManager = @GtkSourceStyleSchemeManager()
        GtkSourceWidget.set_search_path(sourceStyleManager,
          Any[Pkg.dir() * "/GtkSourceWidget/share/gtksourceview-3.0/styles/",C_NULL])

        languageDefinitions = Dict{AbstractString,GtkSourceWidget.GtkSourceLanguage}()
        sourceLanguageManager = GtkSourceWidget.sourceLanguageManager

        languageDefinitions[".jl"] = GtkSourceWidget.language(sourceLanguageManager,"julia")
        languageDefinitions[".md"] = GtkSourceWidget.language(sourceLanguageManager,"markdown")

        @static if is_windows()
            main_style = style_scheme(sourceStyleManager,"visualcode")
            fontsize = opt("fontsize")
            fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
                font-family: Consolas, Courier, monospace;
                font-size: $(fontsize)pt;
            }"""
        end
        @static if is_apple()
            main_style = style_scheme(sourceStyleManager,"visualcode")
            fontsize = opt("fontsize")
            fontCss =  "button, entry, window, sourceview, textview {
                font-family: Monaco, Consolas, Courier, monospace;
                font-size: $(fontsize)pt;
            }"
        end

        @static if is_linux()
            main_style = style_scheme(sourceStyleManager,"tango")
            fontsize = opt("fontsize")-1
            fontCss =  """GtkButton, GtkEntry, GtkWindow, GtkSourceView, GtkTextView {
                font-family: Consolas, Courier, monospace;
                font-size: $(fontsize)pt;
            }"""
        end

        provider = GtkExtensions.default_css_provider
        provider = GtkCssProviderFromData!(provider,data=fontCss)
        GtkIconThemeAddResourcePath(GtkIconThemeGetDefault(), joinpath(HOMEDIR,"../icons/"))

        new(
            languageDefinitions,
            main_style,
            fontsize,
            fontCss,
            provider
        )
    end
end
