module Oxygen

include("core.jl"); using .Core
# Load any optional extensions
include("extensions/load.jl");

using .Core: Context
const CONTEXT = Ref{Context}(Context())

import HTTP
const SERVER = Ref{Union{HTTP.Server, Nothing}}(nothing) 

using DataStructures: CircularDeque
using .Core.Metrics: HTTPTransaction
const HISTORY = Ref{CircularDeque{HTTPTransaction}}(CircularDeque{HTTPTransaction}(1_000_000))

include("methods.jl")
include("deprecated.jl")


export @get, @post, @put, @patch, @delete, @route, @cron, 
        @staticfiles, @dynamicfiles, staticfiles, dynamicfiles,
        get, post, put, patch, delete, route,
        serve, serveparallel, terminate, internalrequest, 
        redirect, queryparams, formdata,
        html, text, json, file, xml, js, json, css, binary,
        configdocs, mergeschema, setschema, getschema, router,
        enabledocs, disabledocs, isdocsenabled, starttasks, stoptasks,
        resetstate, startcronjobs, stopcronjobs, clearcronjobs
end
