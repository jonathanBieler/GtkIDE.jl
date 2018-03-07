using ClusterManagers
@schedule ClusterManagers.elastic_worker("gtkide"; stdout_to_master=false)

while myid() == 1
    sleep(0.01)
end

remotecall(include_string,1,"
    eval(GtkIDE,:(
        add_worker_cb( $(myid()) ) 
    ))
")

#import Base.Distributed.myid
#myid() = 1 #hack to allow for precompilation