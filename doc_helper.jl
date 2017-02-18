for n in names(Actions,true)
    v = eval(Actions,n)
    if typeof(v) == Action
    
        docont = false
        for i in names(GdkKeySyms,true)
            vk = eval(GdkKeySyms,i)
            if typeof(vk) <: Integer
                if v.keyval == vk
                    docont = true
                    break
                end
            end
        end
        docont && continue
    
        k = gdk_keyval_name(v.keyval)
        s = ""
        if v.state == PrimaryModifier
            s = "Ctrl"
        elseif v.state == PrimaryModifier + GdkModifierType.SHIFT
            s = "Ctrl+Shift"
        elseif v.state == SecondaryModifer
            s = "Alt"
        end
        if s != ""
            d = v.description
            println( "- `$s+$k` $d.")
        end
    end
end