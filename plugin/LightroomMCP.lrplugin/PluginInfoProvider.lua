local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrSocket = import 'LrSocket'
local LrPrefs = import 'LrPrefs'
local LrView = import 'LrView'
local LrUUID = import 'LrUUID'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local JSON = require 'JSON'
local HandlerSearch = require 'HandlerSearch'
local HandlerCollections = require 'HandlerCollections'
local HandlerMetadata = require 'HandlerMetadata'
local HandlerOrganization = require 'HandlerOrganization'
local HandlerImport = require 'HandlerImport'
local HandlerExport = require 'HandlerExport'
local HandlerSelection = require 'HandlerSelection'
local HandlerDevelop = require 'HandlerDevelop'
local Log = require 'Log'

local DEFAULT_REQUEST_PORT = 58763
local DEFAULT_RESPONSE_PORT = 58764

-- LrSocket fires these on its accept-loop when no client is attached yet.
-- Both are benign listen-side states, not real failures.
local function isNoClientError(errStr)
    if errStr == "timeout" then return true end
    if errStr:find("failed to open", 1, true) then return true end
    return false
end

local function validPort(n)
    return type(n) == "number" and n == math.floor(n) and n >= 1 and n <= 65535
end

local function readPortPrefs()
    local prefs = LrPrefs.prefsForPlugin()
    local req = tonumber(prefs.requestPort)
    local res = tonumber(prefs.responsePort)
    if not validPort(req) then req = DEFAULT_REQUEST_PORT end
    if not validPort(res) then res = DEFAULT_RESPONSE_PORT end
    return req, res
end

-- State on _G so it survives across re-execution of this module body
-- within the same Lua state. This body runs BOTH when PluginInit requires
-- it AND every time Lightroom loads it as the InfoProvider to render the
-- Plug-in Manager panel. A render must NOT disturb a running server, so we
-- only ever CREATE state here (when absent) — never tear it down. Teardown
-- of a stale prior instance on Reload Plug-in is handled by resetForReload,
-- which PluginInit calls (PluginInit's LrInitPlugin runs on load/reload but
-- NOT on a plain panel render). Tearing down from this body — as earlier
-- versions did when running == true — killed the live server every time the
-- Plug-in Manager was opened (issues #121, #137).
if not _G.LightroomMCP_State then
    _G.LightroomMCP_State = {
        running = false,
        requestSocket = nil,
        responseSocket = nil,
        sendConnected = false,
        receiveConnected = false,
        requestsProcessed = 0,
        lastEvent = nil,
        log = {},
        token = nil,
        lastRequestTime = nil,
        lastConnectedTime = nil,
        needsFullRestart = false,
        freshRestart = false,
        inFlightRequests = 0,
        requestQueue = {},
        queueRunning = false,
        queueGeneration = 0,
        queueAccepting = false,
        queueWorkerGeneration = nil,
        queueWorkerQueue = nil,
    }
end

local pluginState = _G.LightroomMCP_State
-- A running session can survive InfoProvider re-evaluation. Backfill queue
-- fields when an older state table predates the serialization gate.
pluginState.requestQueue = pluginState.requestQueue or {}
pluginState.queueRunning = pluginState.queueRunning or false
pluginState.queueGeneration = pluginState.queueGeneration or 0
if pluginState.queueAccepting == nil then
    -- Preserve a live pre-generation server across InfoProvider re-evaluation;
    -- old state tables do not have the acceptance flag yet.
    pluginState.queueAccepting = pluginState.running == true
end

local function tokenDir()
    return LrPathUtils.child(LrPathUtils.getStandardFilePath("home"), ".config")
end

local function tokenFilePath()
    return LrPathUtils.child(LrPathUtils.child(tokenDir(), "lightroom-mcp"), "token")
end

local function addLog(msg)
    table.insert(pluginState.log, os.date("%H:%M:%S") .. " - " .. msg)
    if #pluginState.log > 100 then
        table.remove(pluginState.log, 1)
    end
    Log.info(msg)
end

local function generateToken()
    -- Two UUIDs (32 hex chars each after stripping dashes) → 256 bits of entropy.
    local u1 = LrUUID.generateUUID():gsub("-", "")
    local u2 = LrUUID.generateUUID():gsub("-", "")
    return (u1 .. u2):lower()
end

local function writeTokenFile(token)
    local dir = LrPathUtils.child(tokenDir(), "lightroom-mcp")
    LrFileUtils.createAllDirectories(dir)
    local path = tokenFilePath()
    local fh, openErr = io.open(path, "w")
    if not fh then
        addLog("Token write failed: " .. tostring(openErr))
        return false
    end
    fh:write(token)
    fh:close()
    -- Lightroom's Lua sandbox has no os.execute, so chmod is impossible here.
    -- On macOS single-user installs ~/.config/ inherits home-dir privacy (700).
    -- On Linux/multi-user systems run: chmod 700 ~/.config/lightroom-mcp
    -- See README "Security" section. Token gates localhost only; threat is
    -- local-user access on the same machine.
    return true
end

local DISPATCH = {
    -- Heartbeat no-op. The MCP server pings on this action every
    -- HEARTBEAT_INTERVAL_SECONDS (server/src/index.ts) so the plugin can
    -- tell a healthy-but-idle session apart from a genuinely dead one
    -- without waiting out a long fixed timer. It travels through the same
    -- auth + dispatch path as any other action, so consumeMessage's
    -- lastRequestTime update (below) already treats it as liveness — no
    -- separate heartbeat bookkeeping needed. See STALE_RECONNECT_SECONDS.
    ping = function(_params) return { pong = true } end,
    search_photos = HandlerSearch.searchPhotos,
    list_collections = HandlerCollections.listCollections,
    create_collection = HandlerCollections.createCollection,
    add_to_collection = HandlerCollections.addToCollection,
    get_photo_metadata = HandlerMetadata.getPhotoMetadata,
    set_keywords = HandlerOrganization.setKeywords,
    set_rating = HandlerOrganization.setRating,
    import_photos = HandlerImport.importPhotos,
    export_photos = HandlerExport.exportPhotos,
    get_selected_photos = HandlerSelection.getSelectedPhotos,
    list_develop_presets = HandlerDevelop.listDevelopPresets,
    get_develop_preset = HandlerDevelop.getDevelopPreset,
    compare_develop_presets = HandlerDevelop.compareDevelopPresets,
    create_develop_preset = HandlerDevelop.createDevelopPreset,
    export_develop_preset = HandlerDevelop.exportDevelopPreset,
    apply_develop_preset = HandlerDevelop.applyDevelopPreset,
    copy_develop_settings = HandlerDevelop.copyDevelopSettings,
    set_develop_settings = HandlerDevelop.setDevelopSettings,
}

-- Generous wait so the very first response after handshake doesn't get
-- dropped while LrSocket is still settling sendConnected on the response
-- side. Must stay below the server's dispatcher timeout (30s) so a real
-- send-side outage still surfaces as a server-side timeout, not silent
-- success.
local SEND_WAIT_SECONDS = 25
-- After this many seconds of waiting for sendConnected, request a fresh
-- response-side rebind. Recovers from states where the response listener
-- ended up bound-but-clientless without responseNeedsRebind being set —
-- observed on Windows in issue #110, where the post-rebind onConnected
-- fires but sendConnected is later false by the time sendResponse runs
-- and no event sets the rebind flag again.
local SEND_REBIND_TRIGGER_SECONDS = 5
-- The MCP server pings every HEARTBEAT_INTERVAL_SECONDS (server/src/index.ts).
-- Treat the connection as stale only after missing roughly three pings in a
-- row, rather than the old fixed 300s idle window. This is what lets a
-- healthy-but-quiet interactive session run indefinitely without tripping a
-- full restart (Automaat review, PR #151: "idle and stale connections are
-- indistinguishable") while still detecting a genuinely dead peer (Windows
-- onClosed unreliability, issue #134) in under two minutes.
local HEARTBEAT_INTERVAL_SECONDS = 30
local STALE_RECONNECT_SECONDS = HEARTBEAT_INTERVAL_SECONDS * 3
-- If a request is in flight when the soft threshold above is hit, give it a
-- chance to finish rather than yanking the socket out from under it — but
-- only up to this hard cap past the soft threshold. If the peer is truly
-- dead the in-flight request was already unrecoverable, so the hard cap
-- guarantees we still restart instead of waiting forever on a hung handler.
-- Bounds the blast radius of a stale-triggered restart (Automaat review,
-- PR #151: "a tool call landing in the restart window loses its response").
local STALE_RESTART_HARD_CAP_SECONDS = STALE_RECONNECT_SECONDS + 30

-- Pure decision extracted from the monitor loop so it can be unit tested
-- without driving the full async LrTasks loop (see PluginInfoProvider_spec.lua).
-- Returns whether to restart and, if so, a log-suffix noting whether the
-- hard cap (not just the soft threshold) is what triggered it.
local function shouldRestartForStaleConnection(idle, inFlightRequests, softSeconds, hardCapSeconds)
    local inFlight = (inFlightRequests or 0) > 0
    local pastSoft = idle > softSeconds
    local pastHard = idle > hardCapSeconds
    local restart = pastSoft and (not inFlight or pastHard)
    local suffix = (inFlight and pastHard) and " [hard cap, request still in flight]" or ""
    return restart, suffix
end

local function sendResponse(response, generation)
    local waited = 0
    local selfHealRequested = false
    while not pluginState.sendConnected and waited < SEND_WAIT_SECONDS do
        if generation and generation ~= pluginState.queueGeneration then
            addLog("Drop stale response id=" .. tostring(response.id) .. " generation=" .. tostring(generation))
            return
        end
        if not selfHealRequested and waited >= SEND_REBIND_TRIGGER_SECONDS then
            addLog("sendResponse stalled " .. SEND_REBIND_TRIGGER_SECONDS .. "s, requesting rebind id=" .. tostring(response.id))
            pluginState.responseNeedsRebind = true
            selfHealRequested = true
        end
        LrTasks.sleep(0.1)
        waited = waited + 0.1
    end
    if generation and generation ~= pluginState.queueGeneration then
        addLog("Drop stale response id=" .. tostring(response.id) .. " generation=" .. tostring(generation))
        return
    end
    if not pluginState.responseSocket or not pluginState.sendConnected then
        addLog("Drop response (send socket disconnected after " .. SEND_WAIT_SECONDS .. "s) id=" .. tostring(response.id))
        return
    end
    local ok, payload = pcall(function() return JSON:encode(response) end)
    if not ok then
        addLog("JSON encode failed: " .. tostring(payload))
        return
    end
    pluginState.responseSocket:send(payload .. "\n")
    pluginState.requestsProcessed = pluginState.requestsProcessed + 1
end

local function dispatchAction(request, generation)
    local id = request.id
    local action = request.action
    local params = request.params or {}

    -- Heartbeat pings arrive every 30s and are pure liveness noise once the
    -- connection is healthy; skip them here so they don't dominate the
    -- 100-line ring buffer used by the status panel and drown out real
    -- request activity.
    local isHeartbeat = (action == "ping")
    if not isHeartbeat then
        addLog("Request id=" .. tostring(id) .. " action=" .. tostring(action))
    end

    -- Tracked so the stale-connection monitor can defer a restart while a
    -- real request is in flight. Held through sendResponse (not just the
    -- handler call) so the monitor can't yank the socket while a response
    -- is still queued waiting on sendConnected (see STALE_RESTART_HARD_CAP_SECONDS).
    pluginState.inFlightRequests = (pluginState.inFlightRequests or 0) + 1

    -- A socket write can fail after the handler has completed. Treat response
    -- delivery as part of request finalization so one broken response cannot
    -- strand the queue worker or leave the stale-connection guard thinking a
    -- request is still active.
    local function sendResponseSafely(response)
        if generation and generation ~= pluginState.queueGeneration then
            addLog("Drop stale response id=" .. tostring(id) .. " generation=" .. tostring(generation))
            return
        end
        local ok, err = LrTasks.pcall(function()
            sendResponse(response, generation)
        end)
        if not ok then
            addLog("Response send error id=" .. tostring(id) .. ": " .. tostring(err))
        end
    end

    local function finalizeRequest()
        pluginState.inFlightRequests = math.max(0, pluginState.inFlightRequests - 1)
    end

    local handler = DISPATCH[action]
    if not handler then
        sendResponseSafely({ id = id, error = "Unknown action: " .. tostring(action) })
        finalizeRequest()
        return
    end

    -- xpcall, debug.traceback, and os.getenv aren't reliably exposed by
    -- Lightroom's Lua sandbox: using them in the dispatcher's error path
    -- turns a handler error into a silent nil-call that never reaches the
    -- client. Stick to LrTasks.pcall.
    local execOk, resultOrErr = LrTasks.pcall(function()
        return handler(params)
    end)
    if execOk then
        sendResponseSafely({ id = id, result = resultOrErr })
    else
        addLog("Handler " .. action .. " error: " .. tostring(resultOrErr))
        sendResponseSafely({ id = id, error = tostring(resultOrErr) })
    end
    finalizeRequest()
end

-- Queue workers capture both their generation and their queue table. A stop,
-- reload, or restart swaps in a new generation/table but leaves an old worker
-- marked active until it returns. This prevents an unfinished selection or
-- catalog mutation from overlapping a newly-started worker.
local startQueueWorker

local function clearQueue(queue, reason)
    queue = queue or {}
    local dropped = #queue
    for i = dropped, 1, -1 do
        queue[i] = nil
    end
    if dropped > 0 then
        addLog("Cleared " .. dropped .. " queued request(s): " .. reason)
    end
end

local function invalidateQueueGeneration(reason)
    local oldQueue = pluginState.requestQueue
    pluginState.queueGeneration = (pluginState.queueGeneration or 0) + 1
    pluginState.queueAccepting = false
    pluginState.requestQueue = {}
    clearQueue(oldQueue, reason)
    if not pluginState.queueRunning then
        pluginState.queueWorkerGeneration = nil
        pluginState.queueWorkerQueue = nil
        pluginState.inFlightRequests = 0
    end
end

local function beginQueueGeneration()
    local oldQueue = pluginState.requestQueue
    pluginState.queueGeneration = (pluginState.queueGeneration or 0) + 1
    pluginState.queueAccepting = false
    pluginState.requestQueue = {}
    clearQueue(oldQueue, "new server generation")
end

local function finalizeQueueWorker(worker)
    local generation = worker.generation
    local queue = worker.queue
    if pluginState.queueWorkerGeneration ~= generation or pluginState.queueWorkerQueue ~= queue then
        -- A worker that no longer owns the state cannot clear or restart it.
        return
    end

    pluginState.queueRunning = false
    pluginState.queueWorkerGeneration = nil
    pluginState.queueWorkerQueue = nil
    if #pluginState.requestQueue == 0 then
        pluginState.inFlightRequests = 0
    end
    -- A stopped/reloaded generation deliberately holds this gate closed while
    -- its old worker is alive. Only the owner cleanup may reopen it, after
    -- which future socket messages can safely enter the new generation.
    if pluginState.running then
        pluginState.queueAccepting = true
    end
    if pluginState.running and pluginState.queueAccepting and #pluginState.requestQueue > 0 then
        startQueueWorker()
    end
end

local function cancelQueueWorker(worker, reason)
    if worker.cancelled then return end
    worker.cancelled = true
    if pluginState.queueWorkerGeneration == worker.generation and pluginState.queueWorkerQueue == worker.queue
        and pluginState.queueGeneration == worker.generation then
        -- Cancellation means this worker must not continue draining its old
        -- queue. Invalidate only its own generation; a stale cleanup callback
        -- must never advance or clear a newer generation.
        invalidateQueueGeneration(reason)
    else
        clearQueue(worker.queue, reason)
    end
end

local function cancelQueueWorkerSafely(worker, reason)
    local cancelOk, cancelErr = LrTasks.pcall(function()
        cancelQueueWorker(worker, reason)
    end)
    if not cancelOk then
        addLog("Queue worker cancellation error generation=" .. tostring(worker.generation) .. ": " .. tostring(cancelErr))
    end
    return cancelOk
end

local function releaseQueueWorker(worker)
    if worker.released then return end
    worker.released = true
    local finalizeOk, finalizeErr = LrTasks.pcall(function()
        finalizeQueueWorker(worker)
    end)
    if not finalizeOk then
        addLog("Queue finalization error generation=" .. tostring(worker.generation) .. ": " .. tostring(finalizeErr))
        if pluginState.queueWorkerGeneration == worker.generation and pluginState.queueWorkerQueue == worker.queue then
            pluginState.queueRunning = false
            pluginState.queueWorkerGeneration = nil
            pluginState.queueWorkerQueue = nil
            pluginState.inFlightRequests = 0
            if pluginState.running then
                pluginState.queueAccepting = true
            end
        end
    end
end

-- Lightroom selection and catalog state are process-wide. Starting one async
-- task per socket message lets two handlers observe or mutate that state at
-- the same time. Keep one worker for the whole plugin and let it drain the
-- captured generation's requests in arrival order.
local function runRequestQueue(generation, queue, worker)
    local workerOk, workerErr = LrTasks.pcall(function()
        while not worker.cancelled and generation == pluginState.queueGeneration and #queue > 0 do
            local request = table.remove(queue, 1)
            local requestsBefore = pluginState.inFlightRequests or 0
            local ok, err = LrTasks.pcall(function()
                dispatchAction(request, generation)
            end)
            if not ok then
                -- Keep draining after an unexpected dispatch error. Handler
                -- and response errors are finalized inside dispatchAction;
                -- this covers malformed requests or SDK surprises that escape
                -- those paths.
                addLog("Dispatch error id=" .. tostring(request.id) .. ": " .. tostring(err))
                if (pluginState.inFlightRequests or 0) > requestsBefore then
                    pluginState.inFlightRequests = math.max(0, pluginState.inFlightRequests - 1)
                end
                if generation == pluginState.queueGeneration then
                    local responseOk, responseErr = LrTasks.pcall(function()
                        sendResponse({ id = request.id, error = tostring(err) }, generation)
                    end)
                    if not responseOk then
                        addLog("Dispatch error response failed id=" .. tostring(request.id) .. ": " .. tostring(responseErr))
                    end
                end
            end
        end
        if worker.cancelled or generation ~= pluginState.queueGeneration then
            clearQueue(queue, "superseded generation")
        end
    end)
    if not workerOk then
        addLog("Queue worker error generation=" .. tostring(generation) .. ": " .. tostring(workerErr))
        clearQueue(queue, "worker error")
    end

end

startQueueWorker = function()
    if pluginState.queueRunning or not pluginState.running or not pluginState.queueAccepting then
        return true
    end
    if #pluginState.requestQueue == 0 then return true end

    local generation = pluginState.queueGeneration
    local queue = pluginState.requestQueue
    local worker = {
        generation = generation,
        queue = queue,
        cancelled = false,
        finished = false,
        released = false,
        cleanupCalled = false,
    }
    pluginState.queueRunning = true
    pluginState.queueWorkerGeneration = generation
    pluginState.queueWorkerQueue = queue

    local ok, err = LrTasks.pcall(function()
        LrFunctionContext.postAsyncTaskWithContext("LightroomMCPQueueWorker", function(context)
            local cleanup = function()
                if worker.cleanupCalled then return end
                worker.cleanupCalled = true
                if not worker.finished then
                    cancelQueueWorkerSafely(worker, "worker context cleanup")
                end
                -- Release even if cancellation itself raised. Lightroom may
                -- invoke cleanup on cancellation before the worker body has
                -- returned, so this handoff must be idempotent.
                releaseQueueWorker(worker)
            end

            local registered, registerErr = LrTasks.pcall(function()
                context:addCleanupHandler(cleanup)
            end)
            if not registered then
                addLog("Queue worker cleanup registration error generation=" .. tostring(generation) .. ": " .. tostring(registerErr))
                cancelQueueWorkerSafely(worker, "worker cleanup registration error")
                worker.finished = true
                releaseQueueWorker(worker)
                return
            end

            local runOk, runErr = LrTasks.pcall(function()
                runRequestQueue(generation, queue, worker)
            end)
            if not runOk then
                addLog("Queue worker task error generation=" .. tostring(generation) .. ": " .. tostring(runErr))
                clearQueue(queue, "worker task error")
            end
            worker.finished = true
            releaseQueueWorker(worker)
        end)
    end)
    if not ok then
        addLog("Queue worker start error generation=" .. tostring(generation) .. ": " .. tostring(err))
        cancelQueueWorkerSafely(worker, "worker start error")
        worker.finished = true
        releaseQueueWorker(worker)
        return false
    end
    return true
end

local function enqueueRequest(request)
    if not pluginState.running or not pluginState.queueAccepting then
        addLog("Drop request while queue stopped id=" .. tostring(request.id))
        return false
    end
    table.insert(pluginState.requestQueue, request)
    return startQueueWorker()
end

-- Runs SYNCHRONOUSLY in onMessage. Every request must carry the current
-- token in `hello`; we authenticate per-message so connection-state
-- races (reload, dual-instance, reconnect) can't desync auth from the
-- live token.
local function consumeMessage(message)
    pluginState.lastEvent = os.date("%H:%M:%S")
    pluginState.lastRequestTime = os.time()  -- track for stale connection detection; a
                                              -- heartbeat ping counts as activity same as
                                              -- any other message.

    local parsedOk, request = pcall(function() return JSON:decode(message) end)
    if not parsedOk or type(request) ~= "table" then
        addLog("JSON decode failed: " .. tostring(message))
        return nil
    end

    if not pluginState.token or request.hello ~= pluginState.token then
        -- Drop silently. We CANNOT call sendResponse here: onMessage runs
        -- in a non-yielding context and sendResponse uses LrTasks.sleep.
        -- Server will time out, which is correct behaviour for auth fail.
        addLog("Auth failed (token mismatch) id=" .. tostring(request.id))
        return nil
    end

    return request
end

local closedSockets = setmetatable({}, { __mode = "k" })

local function closeSocket(socket)
    if not socket or closedSockets[socket] then return end
    closedSockets[socket] = true
    local closeOk = LrTasks.pcall(function() socket:close() end)
    if not closeOk then
        -- A failed close may still be retried by the owning context cleanup.
        closedSockets[socket] = nil
    end
end

-- Invalidate the shared server state before a new instance can bind. The
-- instance id is bumped first so an old loop/callback cannot revive itself
-- when Stop is followed immediately by Start and `running` becomes true
-- again. Old worker ownership is intentionally retained by
-- invalidateQueueGeneration until its context cleanup releases it.
local function retireServerInstance(reason)
    pluginState.instanceId = (pluginState.instanceId or 0) + 1
    pluginState.running = false
    pluginState.queueAccepting = false
    invalidateQueueGeneration(reason)

    local requestSocket = pluginState.requestSocket
    local responseSocket = pluginState.responseSocket
    pluginState.requestSocket = nil
    pluginState.responseSocket = nil
    closeSocket(requestSocket)
    closeSocket(responseSocket)
    pluginState.sendConnected = false
    pluginState.receiveConnected = false
    pluginState.requestNeedsReconnect = false
    pluginState.responseNeedsRebind = false
    pluginState.responseNeedsReconnect = false
    pluginState.token = nil
end

local function startServer()
    if pluginState.running then
        addLog("Already running")
        return
    end
    -- Set running immediately after the guard so check-and-set is atomic.
    -- generateToken/writeTokenFile/readPortPrefs below can yield the
    -- cooperative LrTasks scheduler (token file I/O), and a second caller
    -- waking in that window would otherwise pass the guard too and bind a
    -- second pair of LrSocket listeners on the same ports.
    -- Retire any old async loop before reusing the state table. This closes
    -- sockets synchronously and makes every old callback stale before a new
    -- generation is allowed to bind.
    retireServerInstance("new server instance")
    pluginState.running = true
    beginQueueGeneration()

    pluginState.token = generateToken()
    if writeTokenFile(pluginState.token) then
        addLog("Token written to " .. tokenFilePath())
    end

    local requestPort, responsePort = readPortPrefs()
    pluginState.requestPort = requestPort
    pluginState.responsePort = responsePort

    -- Tag this invocation. resetForReload reuses the same _G state table in
    -- place, so a prior instance's async context-cleanup handler (registered
    -- below) and this fresh start share one table. The id was bumped by
    -- retireServerInstance before token I/O, so old loops are stale even if
    -- token generation or preference reads yield.
    local instanceId = pluginState.instanceId
    addLog("Starting LrSocket servers")

    local serverTask = function(context)
        local requestSocket
        local responseSocket
        local cleanupDone = false
        local function isCurrentInstance()
            return pluginState.instanceId == instanceId
        end

        context:addCleanupHandler(function()
            if cleanupDone then return end
            cleanupDone = true
            if not isCurrentInstance() then
                -- A newer startServer owns the shared state table. The old
                -- callback must not touch that state, but it still owns local
                -- socket handles that need closing to avoid a leaked bind.
                addLog("Stale cleanup (instance " .. instanceId .. " superseded)")
                closeSocket(requestSocket)
                closeSocket(responseSocket)
                return
            end
            addLog("Server task context cleanup")
            -- Bump before teardown so callbacks firing synchronously from
            -- close() cannot mutate the state being retired.
            pluginState.instanceId = instanceId + 1
            pluginState.running = false
            invalidateQueueGeneration("server context cleanup")
            local sharedRequestSocket = pluginState.requestSocket
            local sharedResponseSocket = pluginState.responseSocket
            pluginState.requestSocket = nil
            pluginState.responseSocket = nil
            closeSocket(sharedRequestSocket)
            closeSocket(sharedResponseSocket)
            if requestSocket ~= sharedRequestSocket then
                closeSocket(requestSocket)
            end
            if responseSocket ~= sharedResponseSocket then
                closeSocket(responseSocket)
            end
            pluginState.sendConnected = false
            pluginState.receiveConnected = false
            pluginState.token = nil
        end)

        if not isCurrentInstance() then
            return
        end

        local function bindRequest()
            return LrSocket.bind {
                functionContext = context,
                plugin = _PLUGIN,
                port = requestPort,
                mode = "receive",
                onConnected = function()
                    if not isCurrentInstance() then return end
                    pluginState.receiveConnected = true
                    pluginState.lastConnectedTime = os.time()
                    -- A stale lastRequestTime from a prior session (e.g. user
                    -- Stop/Start after the connection sat idle >90s) must not
                    -- leak into this connection's idle clock, or the monitor
                    -- loop sees a huge idle value on the very first tick and
                    -- restarts immediately. Idle now starts from
                    -- lastConnectedTime until the first real message arrives.
                    pluginState.lastRequestTime = nil
                    if pluginState.freshRestart then
                        -- Sockets were fully closed and rebound by the stale-detection
                        -- restart (issue #134 Windows workaround). The response listener
                        -- already accepted a fresh MCP client; no stale send-side
                        -- connection to flush. Skipping the rebind prevents the
                        -- request->response->request cycling that delays the first
                        -- post-restart response past the 30 s MCP timeout.
                        pluginState.freshRestart = false
                        addLog("REQUEST socket connected (post-restart)")
                    else
                        -- New request client on a live server = new MCP session. Force
                        -- a response-side rebind: LrSocket send-mode does not reliably
                        -- notice client disconnect on Windows, so sendConnected can stay
                        -- true pointing at a dead socket and :send() writes to the void.
                        pluginState.sendConnected = false
                        pluginState.responseNeedsRebind = true
                        addLog("REQUEST socket connected")
                    end
                end,
                onMessage = function(_, message)
                    if not isCurrentInstance() then return end
                    local request = consumeMessage(message)
                    if request then
                        enqueueRequest(request)
                    end
                end,
                onClosed = function()
                    if not isCurrentInstance() then return end
                    pluginState.receiveConnected = false
                    pluginState.requestNeedsReconnect = true
                    addLog("REQUEST socket closed (client disconnected)")
                end,
                onError = function(_, err)
                    if not isCurrentInstance() then return end
                    local errStr = tostring(err)
                    if isNoClientError(errStr) then
                        if not pluginState.receiveConnected then
                            pluginState.requestNeedsReconnect = true
                        end
                    else
                        pluginState.receiveConnected = false
                        pluginState.requestNeedsReconnect = true
                        addLog("REQUEST socket error: " .. errStr)
                    end
                end,
            }
        end

        -- Each rebind bumps a generation. Old-listener callbacks compare
        -- their captured gen to the live one and ignore themselves if
        -- stale. Without this, an onError/onClosed from the just-closed
        -- listener can flag rebind AGAIN immediately after we just
        -- finished rebinding, looping us out of the new client.
        pluginState.responseGen = 0
        -- Clear loop-control flags so a reused state table (in-place
        -- resetForReload, or a panel Stop->Start) doesn't enter the monitor
        -- loop with a stale reconnect/rebind pending and churn the sockets we
        -- just bound on the first tick.
        pluginState.requestNeedsReconnect = false
        pluginState.responseNeedsRebind = false
        pluginState.responseNeedsReconnect = false

        -- bindResponse takes myGen explicitly so callers can pre-bump the
        -- generation BEFORE calling :close() on the prior listener. On
        -- platforms where LrSocket invokes onClosed synchronously during
        -- close (suspected on Windows, per issue #110), a stale callback
        -- would otherwise see isLive()==true and re-set responseNeedsRebind
        -- after we just cleared it.
        local function bindResponse(myGen)
            local function isLive() return isCurrentInstance() and pluginState.responseGen == myGen end
            return LrSocket.bind {
                functionContext = context,
                plugin = _PLUGIN,
                port = responsePort,
                mode = "send",
                onConnected = function()
                    if not isLive() then return end
                    pluginState.sendConnected = true
                    addLog("RESPONSE socket connected")
                end,
                onClosed = function()
                    if not isLive() then return end
                    pluginState.sendConnected = false
                    pluginState.responseNeedsRebind = true
                    addLog("RESPONSE socket closed (gen=" .. myGen .. ")")
                end,
                onError = function(_, err)
                    if not isLive() then return end
                    local errStr = tostring(err)
                    if isNoClientError(errStr) then
                        if not pluginState.sendConnected then
                            pluginState.responseNeedsReconnect = true
                        end
                    else
                        pluginState.sendConnected = false
                        pluginState.responseNeedsRebind = true
                        addLog("RESPONSE socket error: " .. errStr)
                    end
                end,
            }
        end

        -- Bump first, then bind, so the initial listener owns gen=1 (any
        -- pre-existing stale callbacks from a Reload Plug-in cycle were
        -- bound against gen=0 and stay ignored).
        pluginState.responseGen = pluginState.responseGen + 1
        requestSocket = bindRequest()
        if not isCurrentInstance() then
            closeSocket(requestSocket)
            return
        end
        pluginState.requestSocket = requestSocket
        addLog("REQUEST bound on " .. requestPort)
        responseSocket = bindResponse(pluginState.responseGen)
        if not isCurrentInstance() then
            closeSocket(responseSocket)
            return
        end
        pluginState.responseSocket = responseSocket
        addLog("RESPONSE bound on " .. responsePort .. " gen=" .. pluginState.responseGen)

        while pluginState.running and isCurrentInstance() do
            if pluginState.requestNeedsReconnect and requestSocket then
                pluginState.requestNeedsReconnect = false
                requestSocket:reconnect()
            end
            -- Response socket has two recovery paths:
            -- - rebind: full close+rebind for true client disconnect
            -- - reconnect: cheap reconnect for listen-side timeouts
            if pluginState.responseNeedsRebind then
                -- Pre-bump gen BEFORE close so any synchronous onClosed
                -- callback fired during close() sees isLive()==false and
                -- ignores itself. Without this, the OLD listener's close
                -- callback re-sets responseNeedsRebind after we clear it
                -- below, looping the rebind on the next tick. Issue #110
                -- suspected Windows trigger.
                pluginState.responseGen = pluginState.responseGen + 1
                local newGen = pluginState.responseGen
                closeSocket(responseSocket)
                pluginState.sendConnected = false
                -- Brief yield so any kernel cleanup of the just-closed
                -- listener completes before we try to bind the same port
                -- again. The actual server-side reconnect takes ~1s, so
                -- 100ms here doesn't meaningfully delay recovery.
                LrTasks.sleep(0.1)
                if not isCurrentInstance() then
                    return
                end
                responseSocket = bindResponse(newGen)
                if not isCurrentInstance() then
                    closeSocket(responseSocket)
                    return
                end
                pluginState.responseSocket = responseSocket
                pluginState.responseNeedsRebind = false
                pluginState.responseNeedsReconnect = false
                addLog("RESPONSE rebound on " .. responsePort .. " gen=" .. newGen)
            elseif pluginState.responseNeedsReconnect and responseSocket then
                pluginState.responseNeedsReconnect = false
                responseSocket:reconnect()
            end
            -- Full restart requested by stale detection
            if pluginState.needsFullRestart then
                pluginState.needsFullRestart = false
                local staleInstanceId = instanceId
                local restartOk, restartErr = LrTasks.pcall(function()
                    LrTasks.startAsyncTask(function()
                        if pluginState.instanceId ~= staleInstanceId or not pluginState.running then
                            return
                        end
                        addLog("Restarting server (stale connection recovery)")
                        retireServerInstance("stale connection restart")
                        LrTasks.sleep(0.5)
                        if pluginState.instanceId == staleInstanceId + 1 and not pluginState.running then
                            startServer()
                        end
                    end)
                end)
                if not restartOk then
                    addLog("Stale restart task start error: " .. tostring(restartErr))
                    if pluginState.instanceId == instanceId then
                        retireServerInstance("stale restart task start error")
                    end
                end
            end
            -- Stale connection detection: Windows LrSocket does not reliably
            -- fire onClosed when the remote MCP server process exits (issue #134).
            -- The MCP server pings every HEARTBEAT_INTERVAL_SECONDS, so as long as
            -- the connection is genuinely alive, lastRequestTime keeps advancing
            -- even with no real tool calls in flight. If receiveConnected is true
            -- but nothing (including a heartbeat) has arrived for
            -- STALE_RECONNECT_SECONDS, the peer is actually gone, not just idle.
            -- Defer past that soft threshold while a real request is in flight,
            -- up to STALE_RESTART_HARD_CAP_SECONDS, so we don't yank the socket
            -- out from under a response that's about to be sent.
            if pluginState.receiveConnected then
                local ref = pluginState.lastRequestTime or pluginState.lastConnectedTime
                if ref then
                    local idle = os.time() - ref
                    local restart, suffix = shouldRestartForStaleConnection(
                        idle, pluginState.inFlightRequests, STALE_RECONNECT_SECONDS, STALE_RESTART_HARD_CAP_SECONDS)
                    if restart then
                        addLog("Stale connection: " .. idle .. "s since last heartbeat, scheduling restart" .. suffix)
                        pluginState.lastRequestTime = nil
                        pluginState.lastConnectedTime = nil
                        pluginState.needsFullRestart = true
                        pluginState.freshRestart = true
                    end
                end
            end
            LrTasks.sleep(0.2)
        end

        addLog("Server loop exiting")
        -- Socket cleanup runs in context:addCleanupHandler above. The loop
        -- condition is instance-scoped, so an old loop cannot be revived by a
        -- subsequent Start resetting the shared `running` flag.
    end
    local startOk, startErr = LrTasks.pcall(function()
        LrFunctionContext.postAsyncTaskWithContext("LightroomMCPServer", serverTask)
    end)
    if not startOk then
        addLog("Server start error: " .. tostring(startErr))
        retireServerInstance("server start error")
        return
    end
    -- A prior generation may still own a live worker after Stop/Reload. Keep
    -- the new server's socket callbacks installed but reject new mutations
    -- until that owner cleanup releases the serialized backend handoff.
    pluginState.queueAccepting = not pluginState.queueRunning
end

local function stopServer()
    if not pluginState.running then
        addLog("Not running; retiring any stale server instance")
        retireServerInstance("stop while inactive")
        return
    end
    addLog("Stopping LrSocket servers")
    retireServerInstance("server stopped")
end

-- Called by PluginInit on plugin load/reload (never on a Plug-in Manager
-- render). Reload re-runs PluginInit while a prior instance's state may
-- still live on _G in the same Lua state, with `running` stale-true and
-- its task context already cancelled by Lightroom. Clear the flag so the
-- subsequent startServer() isn't blocked by its "Already running" guard,
-- and signal any surviving monitor loop to exit. Reset IN PLACE (not a new
-- table) so this module's pluginState and the old loop's closure keep
-- pointing at the same table — the instance id and running flag together
-- invalidate the old loop and its callbacks.
local function resetForReload()
    if pluginState.running then
        addLog("Reload detected - resetting previous server instance")
    elseif pluginState.queueRunning or #pluginState.requestQueue > 0 then
        addLog("Reload detected - resetting pending queue state")
    elseif pluginState.requestSocket or pluginState.responseSocket then
        addLog("Reload detected - retiring stale server sockets")
    else
        return
    end
    retireServerInstance("plugin reload")
    -- Return the rest of the transient runtime state to fresh-state defaults
    -- so the Plug-in Manager reports honest status after a reload (no
    -- carried-over lastEvent / counters / ports) and the next startServer
    -- can't inherit a stale reconnect/rebind request. instanceId is
    -- deliberately NOT reset -- it must keep advancing so a superseded
    -- instance's cleanup handler stays a no-op (see startServer).
    pluginState.requestNeedsReconnect = false
    pluginState.responseNeedsRebind = false
    pluginState.responseNeedsReconnect = false
    pluginState.lastEvent = nil
    pluginState.requestsProcessed = 0
    pluginState.requestPort = nil
    pluginState.responsePort = nil
    pluginState.lastRequestTime = nil
    pluginState.lastConnectedTime = nil
    pluginState.needsFullRestart = false
    pluginState.freshRestart = false
    if not pluginState.queueRunning then
        pluginState.inFlightRequests = 0
    end
end

addLog("PluginInfoProvider loaded")

local PluginInfoProvider = {
    startServer = startServer,
    stopServer = stopServer,
    resetForReload = resetForReload,
    -- Exposed for PluginInfoProvider_spec.lua only; not used elsewhere in the plugin.
    shouldRestartForStaleConnection = shouldRestartForStaleConnection,
    handlePing = DISPATCH.ping,
    HEARTBEAT_INTERVAL_SECONDS = HEARTBEAT_INTERVAL_SECONDS,
    STALE_RECONNECT_SECONDS = STALE_RECONNECT_SECONDS,
    STALE_RESTART_HARD_CAP_SECONDS = STALE_RESTART_HARD_CAP_SECONDS,
}

function PluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    local prefs = LrPrefs.prefsForPlugin()
    if prefs.autoStartServer == nil then
        prefs.autoStartServer = true
    end
    propertyTable.autoStartServer = prefs.autoStartServer
    propertyTable:addObserver('autoStartServer', function(_, _, value)
        prefs.autoStartServer = value
    end)

    local cfgRequestPort, cfgResponsePort = readPortPrefs()
    propertyTable.requestPort = cfgRequestPort
    propertyTable.responsePort = cfgResponsePort
    propertyTable:addObserver('requestPort', function(_, _, value)
        local n = tonumber(value)
        if validPort(n) then prefs.requestPort = n end
    end)
    propertyTable:addObserver('responsePort', function(_, _, value)
        local n = tonumber(value)
        if validPort(n) then prefs.responsePort = n end
    end)

    local activeRequest = pluginState.requestPort or cfgRequestPort
    local activeResponse = pluginState.responsePort or cfgResponsePort

    local statusText = "=== Lightroom MCP Status ===\n\n"
    statusText = statusText .. "Running: " .. tostring(pluginState.running) .. "\n"
    statusText = statusText .. "Request socket connected: " .. tostring(pluginState.receiveConnected) .. "\n"
    statusText = statusText .. "Response socket connected: " .. tostring(pluginState.sendConnected) .. "\n"
    statusText = statusText .. "Last event: " .. (pluginState.lastEvent or "Never") .. "\n"
    statusText = statusText .. "Requests processed: " .. pluginState.requestsProcessed .. "\n"
    statusText = statusText .. "Request port: " .. activeRequest .. " (mode=receive)\n"
    statusText = statusText .. "Response port: " .. activeResponse .. " (mode=send)\n"
    statusText = statusText .. "Log file: " .. (Log.filePath() or "(unavailable)") .. "\n"
    statusText = statusText .. "\nRecent logs:\n"
    local startIdx = math.max(1, #pluginState.log - 15)
    for i = startIdx, #pluginState.log do
        statusText = statusText .. "  " .. pluginState.log[i] .. "\n"
    end

    return {
        {
            title = "Lightroom MCP Server Status",
            f:static_text {
                title = statusText,
                fill_horizontal = 1,
                width_in_chars = 70,
                height_in_lines = 25,
            },
            f:checkbox {
                title = "Auto-start server on Lightroom launch",
                value = LrView.bind('autoStartServer'),
            },
            f:row {
                f:static_text { title = "Request port:", width = 110 },
                f:edit_field {
                    value = LrView.bind('requestPort'),
                    width_in_chars = 7,
                    precision = 0,
                    min = 1,
                    max = 65535,
                },
                f:static_text { title = "(default 58763)" },
            },
            f:row {
                f:static_text { title = "Response port:", width = 110 },
                f:edit_field {
                    value = LrView.bind('responsePort'),
                    width_in_chars = 7,
                    precision = 0,
                    min = 1,
                    max = 65535,
                },
                f:static_text { title = "(default 58764)" },
            },
            f:static_text {
                title = "Port changes apply on next Start. Server env vars must match: LIGHTROOM_MCP_REQUEST_PORT / LIGHTROOM_MCP_RESPONSE_PORT.",
                fill_horizontal = 1,
                width_in_chars = 70,
                height_in_lines = 2,
            },
            f:row {
                f:push_button {
                    title = pluginState.running and "Stop Server" or "Start Server",
                    action = function()
                        if pluginState.running then
                            stopServer()
                        else
                            startServer()
                        end
                    end,
                },
                f:push_button {
                    title = "Show Status",
                    action = function()
                        local lines = {
                            "Running: " .. tostring(pluginState.running),
                            "Request socket connected: " .. tostring(pluginState.receiveConnected),
                            "Response socket connected: " .. tostring(pluginState.sendConnected),
                            "Last event: " .. (pluginState.lastEvent or "Never"),
                            "Requests processed: " .. pluginState.requestsProcessed,
                            "Log file: " .. (Log.filePath() or "(unavailable)"),
                            "",
                            "Recent logs:",
                        }
                        local logStart = math.max(1, #pluginState.log - 30)
                        for i = logStart, #pluginState.log do
                            table.insert(lines, "  " .. pluginState.log[i])
                        end
                        LrDialogs.message("Lightroom MCP Status", table.concat(lines, "\n"), "info")
                    end,
                },
            },
        },
    }
end

return PluginInfoProvider
