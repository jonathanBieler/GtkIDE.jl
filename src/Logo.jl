## draw a GtkIDE logo

function logo()

    circle(t, r, c, opt) = layer(x=r[1]*sin.(2π*t)+c[1], y=r[2]*cos.(2π*t)+c[2], opt...)
    line(t, v, c, opt) = layer(x=v[1]*t+c[1], y=v[2]*t+c[2], opt...)

    c0 = Colors.RGBA(0.15, 0.15, 0.15, 0.9)
    c1 = Colors.RGBA(107/255, 171/255, 91/255, 0.9)
    c2 = Colors.RGBA(0.84, 0.4, 0.38, 0.9)
    c3 = Colors.RGBA(0.67, 0.49, 0.75, 0.9)

    xt = range(0, stop=1, length=25)
    xt = xt.^4 ./ (0.3.^4 + xt.^4)

    opt  = (Geom.point, Theme(default_color=c0, highlight_width=0pt, point_size=3pt))
    opt1 = (Geom.point, Theme(default_color=c1, highlight_width=0pt, point_size=3pt))
    opt2 = (Geom.point, Theme(default_color=c2, highlight_width=0pt, point_size=3pt))
    opt3 = (Geom.point, Theme(default_color=c3, highlight_width=0pt, point_size=3pt))

    for maxt in xt

        t = collect(range(0, stop=maxt, length=90))
       
        spacing = 0.3 + maxt/15
        h = 1.6
        
        p = plot(
            #G
            circle(t/2+0.5, (0.6, 0.8), (0, 0.8), opt),
            line(t, (0, 0.6), (0, 0), opt),
            circle(-t/5 -0.5, (0.2, 0.2), (0, 0.8), opt),
            #T
            line(t, (0, h*2/3), (spacing, 0), opt),
            line(t, (0.5, 0), (spacing-0.25, h*2/3), opt),
            #K
            line(t, (0, h*2/3), (2*spacing, 0), opt),
            line(t, (1/3, 1/3), (2*spacing, h/4), opt),
            line(t, (1/3, -0.45), (2*spacing+0.05, h/4+0.05), opt),
            # I
            line(t, (0, h), (3*spacing+0.1, 0), opt1),
            # D
            line(t, (0, h), (4*spacing-0.1, 0), opt2),
            circle(t/2, (0.6, 0.8), (4*spacing-0.1, 0.8), opt2),
            # E
            line(t, (0, h), (6*spacing-0.1, 0), opt3),
            line(t, (0.6, 0), (6*spacing-0.1, 0), opt3),
            line(t, (0.5, 0), (6*spacing-0.1, h/2), opt3),
            line(t, (0.6, 0), (6*spacing-0.1, h), opt3),
            #
            Coord.cartesian(fixed=true, xmin=-0.8, xmax=6*spacing+0.8, ymin=-0.2, ymax=1.8),
            Guide.xticks(ticks=nothing), Guide.yticks(ticks=nothing),
            Guide.xlabel(""), Guide.ylabel(""),
            
        )
        display(p)
        sleep(0.01)
        
    end
    sleep(0.1)
    display(plot(x=xt, y=sin.(2π*xt), Geom.line))

end