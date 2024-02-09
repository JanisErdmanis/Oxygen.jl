# This is where methods are coupled to a global state

"""
Reset all the internal state variables
"""
function resetstate()
    # reset this modules state variables 
    Core.timers[] = []         

    # This no longer is done at this level
    # perhaps it should be done at the topmost level

    SERVER[] = nothing

    CONTEXT[] = Context()

    Core.resetstatevariables()
    # reset cron module state
    Core.resetcronstate()
    # clear metrics
    empty!(HISTORY[])
end

# Nothing to do for the router
"""
    terminate(ctx)

stops the webserver immediately
"""
function terminate()
    if !isnothing(SERVER[]) && isopen(SERVER[])
        # stop background cron jobs
        Core.stopcronjobs()
        # stop background tasks
        Core.stoptasks()
        # stop server
        close(SERVER[])
    end
end

function serve(; 
      middleware::Vector=[], 
      handler=Core.stream_handler, 
      host="127.0.0.1", 
      port=8080, 
      serialize=true, 
      async=false, 
      catch_errors=true, 
      docs=true,
      metrics=true, 
      show_errors=true,               
      kwargs...) 

    
    try

        SERVER[] = Core.serve(CONTEXT[], HISTORY[]; 
                 middleware, handler, port, serialize, 
                 async, catch_errors, show_errors, docs, metrics, kwargs...)

        return SERVER[]

    finally
        
        # close server on exit if we aren't running asynchronously
        if !async 
            terminate()
        end

        # only reset state on exit if we aren't running asynchronously & are running it interactively 
        if !async && isinteractive()
            resetstate()
        end

    end
end



function serveparallel(; 
                       middleware::Vector=[], 
                       handler=Core.stream_handler, 
                       host="127.0.0.1", 
                       port=8080, 
                       queuesize=1024, 
                       serialize=true, 
                       async=false, 
                       catch_errors=true,
                       docs=true,
                       metrics=true, 
                       show_errors=true,
                       kwargs...)

    # Moved from `streamutil.jl` start method
    streamhandler = Core.StreamUtil.Handler()

    #HANDLER[] = Handler()

    try

        SERVER[] = Core.serveparallel(CONTEXT[], HISTORY[], streamhandler;                  
                         middleware, handler, port, queuesize, serialize, 
                         async, catch_errors, show_errors, docs, metrics, kwargs...)

        return SERVER[]

    finally 

        # close server on exit if we aren't running asynchronously
        if !async 
            terminate()
            # stop any background worker threads
            Core.StreamUtil.stop(streamhandler)
        end

        # only reset state on exit if we aren't running asynchronously & are running it interactively 
        if !async && isinteractive()
            resetstate()
        end

    end
end


### Routing Macros ###

"""
    @get(path::String, func::Function)

Used to register a function to a specific endpoint to handle GET requests  
"""
macro get(path, func)
    :(@route ["GET"] $(esc(path)) $(esc(func)))
end

"""
    @post(path::String, func::Function)

Used to register a function to a specific endpoint to handle POST requests
"""
macro post(path, func)
    :(@route ["POST"] $(esc(path)) $(esc(func)))
end

"""
    @put(path::String, func::Function)

Used to register a function to a specific endpoint to handle PUT requests
"""
macro put(path, func)
    :(@route ["PUT"] $(esc(path)) $(esc(func)))
end

"""
    @patch(path::String, func::Function)

Used to register a function to a specific endpoint to handle PATCH requests
"""
macro patch(path, func)
    :(@route ["PATCH"] $(esc(path)) $(esc(func)))
end

"""
    @delete(path::String, func::Function)

Used to register a function to a specific endpoint to handle DELETE requests
"""
macro delete(path, func)
    :(@route ["DELETE"] $(esc(path)) $(esc(func)))
end

"""
    @route(methods::Array{String}, path::String, func::Function)

Used to register a function to a specific endpoint to handle mulitiple request types
"""
macro route(methods, path, func)
    :(route($(esc(methods)), $(esc(path)), $(esc(func))))
end



### Core Routing Functions ###

function route(methods::Vector{String}, path::Union{String,Function}, func::Function)
    for method in methods
        Core.register(CONTEXT[], method, path, func)
    end
end

# This variation supports the do..block syntax
route(func::Function, methods::Vector{String}, path::Union{String,Function}) = route(methods, path, func)

### Core Routing Functions Support for do..end Syntax ###

Base.get(func::Function, path::String)      = route(["GET"], path, func)
Base.get(func::Function, path::Function)    = route(["GET"], path, func)

post(func::Function, path::String)          = route(["POST"], path, func)
post(func::Function, path::Function)        = route(["POST"], path, func)

put(func::Function, path::String)           = route(["PUT"], path, func) 
put(func::Function, path::Function)         = route(["PUT"], path, func) 

patch(func::Function, path::String)         = route(["PATCH"], path, func)
patch(func::Function, path::Function)       = route(["PATCH"], path, func)

delete(func::Function, path::String)        = route(["DELETE"], path, func)
delete(func::Function, path::Function)      = route(["DELETE"], path, func)



"""
    @staticfiles(folder::String, mountdir::String, headers::Vector{Pair{String,String}}=[])

Mount all files inside the /static folder (or user defined mount point)
"""
macro staticfiles(folder, mountdir="static", headers=[])
    printstyled("@staticfiles macro is deprecated, please use the staticfiles() function instead\n", color = :red, bold = true) 
    quote
        staticfiles($(esc(folder)), $(esc(mountdir)); headers=$(esc(headers))) 
    end
end


"""
    @dynamicfiles(folder::String, mountdir::String, headers::Vector{Pair{String,String}}=[])

Mount all files inside the /static folder (or user defined mount point), 
but files are re-read on each request
"""
macro dynamicfiles(folder, mountdir="static", headers=[])
    printstyled("@dynamicfiles macro is deprecated, please use the dynamicfiles() function instead\n", color = :red, bold = true) 
    quote
        dynamicfiles($(esc(folder)), $(esc(mountdir)); headers=$(esc(headers))) 
    end      
end


staticfiles(
    folder::String, 
    mountdir::String="static"; 
    headers::Vector=[], 
    loadfile::Union{Function,Nothing}=nothing
) = Core.staticfiles(CONTEXT[], folder, mountdir; headers, loadfile)


dynamicfiles(
    folder::String, 
    mountdir::String="static"; 
    headers::Vector=[], 
    loadfile::Union{Function,Nothing}=nothing
) = Core.dynamicfiles(CONTEXT[], folder, mountdir; headers, loadfile)


internalrequest(req::HTTP.Request; middleware::Vector=[], metrics::Bool=true, serialize::Bool=true, catch_errors=true) = Core.internalrequest(CONTEXT[].router, CONTEXT[].custommiddleware, HISTORY[], req; middleware, metrics, serialize, catch_errors)


function router(prefix::String = ""; 
                tags::Vector{String} = Vector{String}(), 
                middleware::Union{Nothing, Vector} = nothing, 
                interval::Union{Real, Nothing} = nothing,
                cron::Union{String, Nothing} = nothing)


    return Core.AutoDoc.router(CONTEXT[], prefix; tags, middleware, interval, cron)
end


# Adding docstrings
@doc (@doc(Core.AutoDoc.router)) router

for method in [:serve, :serveparallel, :staticfiles, :dynamicfiles, :internalrequest]
    eval(quote
        @doc (@doc(Core.$method)) $method
    end)
end
