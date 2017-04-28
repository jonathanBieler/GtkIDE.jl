# Refactoring.arguments

args(x) = GtkIDE.Refactoring.arguments(x)

@assert args(Expr(:block,:x)) == Symbol[:x]

@assert args(:(x = 2)) == Symbol[]

@assert args(:(x,y = 1,2)) == Symbol[]
@assert args(:(x,y,z,k = 1,2,3,4)) == Symbol[]

@assert args(:(x,y[1],z,k = 1,2,3,4)) == Symbol[]
@assert args(:(x,y[i],z,k = 1,2,3,4)) == Symbol[:i]

@assert args(:(x,y[i],z,k = 1,a,3,4)) == Symbol[:i,:a]

#@assert args(:(x,y[i[k]],z,k = 1,2,3,4)) == Symbol[:i,:k] #fail

@assert args(:(x = y)) == Symbol[:y]

#@assert args(:(f(x,y) =  x + y*a) ) == [:a]

@assert args(:(f(a,b,c))) == Symbol[:a,:b,:c]

@assert args(quote 
    x,y,z,k = 1,2,3,4
    g = x*y
end) == Symbol[]

@assert args(quote 
    x,y,z,k = 1,c,3,4
    g = x*d
end) == Symbol[:c,:d]

ex = quote
    using Gadfly
    mu = K1
    const alpha = 1
    const beta = (alpha+1)*mu

    for i=1:10
        x = rand(100,x,f(K2)) 
    end

    plot(x=K3,y=pdf(InverseGamma(K4,beta),K5),Geom.line)
    
    ind, K7 = K6.asd
    x = K8[K7]
end
@assert args(ex) == [:K1,:K2,:K3,:K4,:K5,:Geom,:K6,:K8] 

ex = quote
    for i=1:10
        x[i] = j
    end
end
@assert args(ex) == [:j] 

ex = quote
    f(ex,b) = a
    ex = f(1,2)
end
@assert args(ex) == [:a] 

# that's too advanced...
#ex = quote
#    y = [x for x = 1:10]
#end
#@assert args(ex) == Symbol[]



