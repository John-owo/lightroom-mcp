local helper = require 'spec_helper'

-- Stub everything PluginInfoProvider / PluginInit pull in so requiring them
-- has no real side effects. The lifecycle logic under test lives in the
-- module body + resetForReload + PluginInit wiring; none of it binds a
-- socket at load time (binding happens only inside startServer).
local HANDLER_MODULES = {
    'JSON', 'HandlerSearch', 'HandlerCollections', 'HandlerMetadata',
    'HandlerOrganization', 'HandlerImport', 'HandlerExport',
    'HandlerSelection', 'HandlerDevelop',
}

-- opts (all optional) let a test drive the otherwise-async server task:
--   runTask        -- actually execute the postAsyncTaskWithContext body
--   cleanups       -- array; each registered cleanup handler is appended
--   socketOps      -- array; "close"/"reconnect" calls on bound sockets land here
--   stopLoopOnSleep -- flip running=false on the first LrTasks.sleep so the
--                      monitor loop exits after a single tick
--   capturedBinds  -- array; each LrSocket.bind opts table is appended, in
--                      bind order (request socket first, then response), so
--                      a test can invoke onConnected/onMessage/etc directly
--   startTaskError -- make LrTasks.startAsyncTask raise the supplied error
--   postTaskError -- make LrFunctionContext.postAsyncTaskWithContext raise
--   queueWorkerStartError -- make the queue worker context start raise
--   workerCleanups -- array; queue-worker cleanup handlers are appended
--   deferServerTask -- retain a server task in serverTasks for manual resume
--   serverTasks -- deferred server task runners
--   yieldOnSleep -- yield deferred coroutine tasks from LrTasks.sleep
--   boundSockets -- array; returned socket objects in bind order
local function installStubs(prefs, asyncTasks, opts)
    opts = opts or {}
    helper.installImport({
        LrTasks = {
            startAsyncTask = function(fn)
                if opts.startTaskError then error(opts.startTaskError) end
                if asyncTasks then
                    table.insert(asyncTasks, fn)
                else
                    fn()
                end
            end,
            sleep = function()
                if opts.stopLoopOnSleep and _G.LightroomMCP_State then
                    _G.LightroomMCP_State.running = false
                end
                local currentCoroutine, isMain = coroutine.running()
                if opts.yieldOnSleep and currentCoroutine and not isMain then
                    coroutine.yield("sleep")
                end
            end,
            pcall = pcall,
        },
        LrLogger = helper.defaultLrLogger(),
        LrDialogs = { message = function() end },
        LrFunctionContext = {
            postAsyncTaskWithContext = function(name, fn)
                if name == "LightroomMCPQueueWorker" then
                    if opts.queueWorkerStartError then error(opts.queueWorkerStartError) end
                    local workerContext = {
                        addCleanupHandler = function(_, handler)
                            if opts.workerCleanups then table.insert(opts.workerCleanups, handler) end
                        end,
                    }
                    local workerTask = function() fn(workerContext) end
                    if asyncTasks then
                        table.insert(asyncTasks, workerTask)
                    else
                        workerTask()
                    end
                    return
                end
                if opts.postTaskError then error(opts.postTaskError) end
                if not opts.runTask then return end
                local context = {
                    addCleanupHandler = function(_, handler)
                        if opts.cleanups then table.insert(opts.cleanups, handler) end
                    end,
                }
                if name == "LightroomMCPServer" and opts.deferServerTask then
                    local taskCoroutine = coroutine.create(function() fn(context) end)
                    local task = function()
                        local resumed, resumeErr = coroutine.resume(taskCoroutine)
                        if not resumed then error(resumeErr) end
                        return coroutine.status(taskCoroutine)
                    end
                    if opts.serverTasks then table.insert(opts.serverTasks, task) end
                    return
                end
                fn(context)
            end,
        },
        LrSocket = {
            bind = function(bindOpts)
                if opts.capturedBinds then table.insert(opts.capturedBinds, bindOpts) end
                local socket
                socket = {
                    closed = false,
                    close = function()
                        socket.closed = true
                        socket.closeCount = socket.closeCount + 1
                        if opts.socketOps then table.insert(opts.socketOps, "close") end
                    end,
                    reconnect = function()
                        if opts.socketOps then table.insert(opts.socketOps, "reconnect") end
                    end,
                    send = function() end,
                    closeCount = 0,
                }
                if opts.boundSockets then table.insert(opts.boundSockets, socket) end
                return socket
            end,
        },
        LrPrefs = { prefsForPlugin = function() return prefs or {} end },
        LrView = { bind = function() end },
        LrUUID = { generateUUID = function() return "0000-0000" end },
        LrPathUtils = {
            child = function(a, b) return a .. "/" .. b end,
            getStandardFilePath = function() return "/home" end,
        },
        LrFileUtils = { createAllDirectories = function() end },
    })
    for _, name in ipairs(HANDLER_MODULES) do
        package.loaded[name] = {}
    end
end

-- Simulate Lightroom loading the InfoProvider file fresh (panel render) or
-- PluginInit requiring it: clear the module cache and re-run its body while
-- _G persists across the load (same Lua state).
local function loadInfoProvider()
    package.loaded.PluginInfoProvider = nil
    return require 'PluginInfoProvider'
end

local function loadPluginInit()
    package.loaded.PluginInfoProvider = nil
    package.loaded.PluginInit = nil
    require 'PluginInit'
end

describe("PluginInfoProvider lifecycle", function()
    before_each(function()
        _G.LightroomMCP_State = nil
        installStubs()
    end)

    it("creates fresh state on first load", function()
        loadInfoProvider()
        assert.is_not_nil(_G.LightroomMCP_State)
        assert.is_false(_G.LightroomMCP_State.running)
    end)

    it("preserves a running server across a Plug-in Manager render", function()
        loadInfoProvider()
        -- Simulate a live server, then a panel render that re-runs the body.
        _G.LightroomMCP_State.running = true
        local sock = { close = function() error("must not close on render") end }
        _G.LightroomMCP_State.requestSocket = sock
        local stateBefore = _G.LightroomMCP_State

        loadInfoProvider()

        assert.are.equal(stateBefore, _G.LightroomMCP_State)
        assert.is_true(_G.LightroomMCP_State.running)
        assert.are.equal(sock, _G.LightroomMCP_State.requestSocket)
    end)

    it("resetForReload stops a stale running instance", function()
        local mod = loadInfoProvider()
        local closed = { request = false, response = false }
        local s = _G.LightroomMCP_State
        s.running = true
        s.token = "tok"
        s.sendConnected = true
        s.receiveConnected = true
        s.requestSocket = { close = function() closed.request = true end }
        s.responseSocket = { close = function() closed.response = true end }

        mod.resetForReload()

        assert.is_false(s.running)
        assert.is_nil(s.requestSocket)
        assert.is_nil(s.responseSocket)
        assert.is_false(s.sendConnected)
        assert.is_false(s.receiveConnected)
        assert.is_nil(s.token)
        assert.is_true(closed.request)
        assert.is_true(closed.response)
    end)

    it("resetForReload is a no-op when nothing is running", function()
        local mod = loadInfoProvider()
        assert.has_no.errors(function() mod.resetForReload() end)
        assert.is_false(_G.LightroomMCP_State.running)
    end)
end)

-- Auto-start scheduling itself is covered by PluginInit_spec.lua; here we
-- only assert that PluginInit wires the reload teardown into the real module.
describe("PluginInit reload reset", function()
    before_each(function()
        _G.LightroomMCP_State = nil
    end)

    it("resets a surviving running instance on reload", function()
        installStubs({ autoStartServer = false })
        local closed = false
        _G.LightroomMCP_State = {
            running = true,
            requestSocket = { close = function() closed = true end },
            responseSocket = nil,
            sendConnected = true,
            receiveConnected = false,
            requestsProcessed = 7,
            lastEvent = "12:00:00",
            requestPort = 12345,
            responseNeedsRebind = true,
            log = {},
            token = "tok",
        }

        loadPluginInit()

        assert.is_false(_G.LightroomMCP_State.running)
        assert.is_nil(_G.LightroomMCP_State.requestSocket)
        assert.is_true(closed)
        -- Transient state returns to fresh-state defaults (Copilot #141).
        assert.are.equal(0, _G.LightroomMCP_State.requestsProcessed)
        assert.is_nil(_G.LightroomMCP_State.lastEvent)
        assert.is_nil(_G.LightroomMCP_State.requestPort)
        assert.is_false(_G.LightroomMCP_State.responseNeedsRebind)
    end)
end)

-- Drives the real startServer task body (binds, cleanup handler, monitor
-- loop) to cover the concurrency-sensitive teardown that the in-place
-- resetForReload refactor put at risk.
describe("PluginInfoProvider server task", function()
    local realOpen
    before_each(function()
        _G.LightroomMCP_State = nil
        -- startServer writes a token file; stub ONLY the write so it never
        -- touches disk. Delegate every other open to the real io.open --
        -- under CI's luarocks `require` loader, manifest reads call
        -- io.open(path):read(), and a fake handle there breaks module loading.
        realOpen = io.open
        io.open = function(path, mode, ...)
            if mode and mode:find("w", 1, true) then
                return { write = function() end, close = function() end }
            end
            return realOpen(path, mode, ...)
        end
    end)
    after_each(function()
        io.open = realOpen
    end)

    it("bumps instanceId on every start", function()
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = {} })
        local mod = loadInfoProvider()

        mod.startServer()
        assert.are.equal(1, _G.LightroomMCP_State.instanceId)
        mod.startServer()
        assert.are.equal(2, _G.LightroomMCP_State.instanceId)
    end)

    it("ignores a superseded instance's cleanup handler", function()
        local cleanups = {}
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = cleanups })
        local mod = loadInfoProvider()

        mod.startServer() -- instance 1: binds, loop exits (stopLoopOnSleep)
        local staleCleanup = cleanups[1]

        mod.startServer() -- instance 2 supersedes
        local liveReq = _G.LightroomMCP_State.requestSocket
        local liveResp = _G.LightroomMCP_State.responseSocket
        local liveToken = _G.LightroomMCP_State.token

        -- Old context cleanup fires late (after the new instance rebound).
        staleCleanup()

        assert.are.equal(liveReq, _G.LightroomMCP_State.requestSocket)
        assert.are.equal(liveResp, _G.LightroomMCP_State.responseSocket)
        assert.are.equal(liveToken, _G.LightroomMCP_State.token)
    end)

    it("retires an old async loop and its callbacks across a rapid stop/start", function()
        local binds = {}
        local serverTasks = {}
        local boundSockets = {}
        local cleanups = {}
        local ops = {}
        installStubs(nil, nil, {
            runTask = true,
            deferServerTask = true,
            serverTasks = serverTasks,
            cleanups = cleanups,
            yieldOnSleep = true,
            capturedBinds = binds,
            boundSockets = boundSockets,
            socketOps = ops,
        })
        local mod = loadInfoProvider()

        mod.startServer()
        assert.are.equal(1, #serverTasks)
        assert.are.equal("suspended", serverTasks[1]())
        local state = _G.LightroomMCP_State
        local oldInstanceId = state.instanceId
        local oldRequest = binds[1]
        local oldResponse = binds[2]
        local oldRequestSocket = boundSockets[1]
        local oldResponseSocket = boundSockets[2]
        assert.are.equal(oldRequestSocket, state.requestSocket)
        assert.are.equal(oldResponseSocket, state.responseSocket)

        mod.stopServer()
        assert.are_not.equal(oldInstanceId, state.instanceId)
        assert.is_true(oldRequestSocket.closed)
        assert.is_true(oldResponseSocket.closed)

        mod.startServer()
        assert.are.equal(2, #serverTasks)
        assert.are.equal("suspended", serverTasks[2]())
        local newRequestSocket = boundSockets[3]
        local newResponseSocket = boundSockets[4]
        state.receiveConnected = true
        state.sendConnected = true
        state.requestNeedsReconnect = false
        state.responseNeedsRebind = false
        state.responseNeedsReconnect = false

        -- Late callbacks from the old listeners must not mutate the new
        -- instance or enqueue a request after the restart.
        oldRequest.onClosed()
        oldRequest.onError(nil, "fatal")
        oldRequest.onMessage(nil, "stale callback")
        oldResponse.onClosed()
        assert.is_true(state.receiveConnected)
        assert.is_true(state.sendConnected)
        assert.is_false(state.requestNeedsReconnect)
        assert.is_false(state.responseNeedsRebind)
        assert.is_false(state.responseNeedsReconnect)

        -- Resuming the retained old loop must observe its stale instance id,
        -- exit, and never bind a second pair of listeners.
        assert.are.equal("dead", serverTasks[1]())
        cleanups[1]() -- stale context cleanup must be harmless after Stop closed it
        cleanups[1]() -- cleanup itself is idempotent
        assert.are.equal(4, #binds)
        assert.are.equal(1, oldRequestSocket.closeCount)
        assert.are.equal(1, oldResponseSocket.closeCount)
        assert.are.equal(0, newRequestSocket.closeCount)
        assert.are.equal(0, newResponseSocket.closeCount)
        assert.are.equal(newRequestSocket, state.requestSocket)
        assert.are.equal(newResponseSocket, state.responseSocket)
    end)

    it("tears down its own sockets when not superseded", function()
        local cleanups = {}
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = cleanups })
        local mod = loadInfoProvider()

        mod.startServer()
        cleanups[1]()

        assert.is_nil(_G.LightroomMCP_State.requestSocket)
        assert.is_nil(_G.LightroomMCP_State.responseSocket)
        assert.is_nil(_G.LightroomMCP_State.token)
    end)

    it("does not churn freshly bound sockets when recovery flags are stale", function()
        local ops = {}
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = {}, socketOps = ops })
        local mod = loadInfoProvider()

        -- Simulate flags left true by a client disconnect just before reload.
        _G.LightroomMCP_State.requestNeedsReconnect = true
        _G.LightroomMCP_State.responseNeedsRebind = true
        _G.LightroomMCP_State.responseNeedsReconnect = true

        mod.startServer()

        assert.are.equal(0, #ops)
        assert.is_false(_G.LightroomMCP_State.requestNeedsReconnect)
        assert.is_false(_G.LightroomMCP_State.responseNeedsRebind)
        assert.is_false(_G.LightroomMCP_State.responseNeedsReconnect)
    end)
end)


describe("stale-connection follow-up fixes (PR #151 re-review)", function()
    local realOpen
    before_each(function()
        _G.LightroomMCP_State = nil
        realOpen = io.open
        io.open = function(path, mode, ...)
            if mode and mode:find("w", 1, true) then
                return { write = function() end, close = function() end }
            end
            return realOpen(path, mode, ...)
        end
    end)
    after_each(function()
        io.open = realOpen
    end)

    it("clears a stale lastRequestTime on a fresh REQUEST connect so it doesn't leak into the new idle clock", function()
        local binds = {}
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = {}, capturedBinds = binds })
        local mod = loadInfoProvider()

        mod.startServer()
        -- Simulate a prior session's activity timestamp surviving past a
        -- manual Stop/Start (or any reconnect) that happens long after it
        -- sat idle. Without clearing it here, the monitor loop's very next
        -- tick would see a huge idle value and restart immediately.
        _G.LightroomMCP_State.lastRequestTime = os.time() - 999
        binds[1].onConnected()

        assert.is_nil(_G.LightroomMCP_State.lastRequestTime)
        assert.is_not_nil(_G.LightroomMCP_State.lastConnectedTime)
    end)

    it("keeps a request counted in-flight until sendResponse actually completes, not just until the handler returns", function()
        package.loaded.JSON = nil -- exercise the real encoder/decoder, not the empty stub
        local binds = {}
        installStubs(nil, nil, { runTask = true, stopLoopOnSleep = true, cleanups = {}, capturedBinds = binds })
        local mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = {
            send = function()
                -- If inFlightRequests were decremented right after the
                -- handler returns (the pre-fix behavior), the monitor loop
                -- could see 0 in-flight and restart the server while this
                -- send is still happening — defeating the blast-radius fix.
                assert.are.equal(1, state.inFlightRequests)
            end,
        }

        binds[1].onMessage(nil, '{"id":1,"action":"ping","hello":"' .. state.token .. '"}')

        assert.are.equal(0, state.inFlightRequests)
    end)
end)

describe("heartbeat / stale-connection blast radius (PR #151 review)", function()
    before_each(function()
        _G.LightroomMCP_State = nil
        installStubs()
    end)

    it("ping handler is a pure liveness no-op returning pong=true", function()
        local mod = loadInfoProvider()
        assert.are.same({ pong = true }, mod.handlePing({}))
    end)

    it("derives the soft/hard thresholds from the heartbeat interval", function()
        local mod = loadInfoProvider()
        assert.are.equal(30, mod.HEARTBEAT_INTERVAL_SECONDS)
        assert.are.equal(90, mod.STALE_RECONNECT_SECONDS)
        assert.are.equal(120, mod.STALE_RESTART_HARD_CAP_SECONDS)
    end)

    describe("shouldRestartForStaleConnection", function()
        it("does not restart while idle is within the soft threshold", function()
            local mod = loadInfoProvider()
            local restart, suffix = mod.shouldRestartForStaleConnection(
                89, 0, mod.STALE_RECONNECT_SECONDS, mod.STALE_RESTART_HARD_CAP_SECONDS)
            assert.is_false(restart)
            assert.are.equal("", suffix)
        end)

        it("restarts once idle passes the soft threshold with nothing in flight", function()
            local mod = loadInfoProvider()
            local restart, suffix = mod.shouldRestartForStaleConnection(
                91, 0, mod.STALE_RECONNECT_SECONDS, mod.STALE_RESTART_HARD_CAP_SECONDS)
            assert.is_true(restart)
            assert.are.equal("", suffix)
        end)

        it("defers the restart past the soft threshold while a request is genuinely in flight (blast radius fix)", function()
            local mod = loadInfoProvider()
            local restart, suffix = mod.shouldRestartForStaleConnection(
                91, 1, mod.STALE_RECONNECT_SECONDS, mod.STALE_RESTART_HARD_CAP_SECONDS)
            assert.is_false(restart)
            assert.are.equal("", suffix)
        end)

        it("still restarts past the hard cap even if a request is in flight, to bound the wait", function()
            local mod = loadInfoProvider()
            local restart, suffix = mod.shouldRestartForStaleConnection(
                121, 1, mod.STALE_RECONNECT_SECONDS, mod.STALE_RESTART_HARD_CAP_SECONDS)
            assert.is_true(restart)
            assert.are.equal(" [hard cap, request still in flight]", suffix)
        end)

        it("treats exactly-at-threshold idle as not yet past it (strict greater-than)", function()
            local mod = loadInfoProvider()
            local restart = mod.shouldRestartForStaleConnection(
                90, 0, mod.STALE_RECONNECT_SECONDS, mod.STALE_RESTART_HARD_CAP_SECONDS)
            assert.is_false(restart)
        end)
    end)
end)

describe("serialized request dispatch", function()
    local realOpen

    before_each(function()
        _G.LightroomMCP_State = nil
        realOpen = io.open
        io.open = function(path, mode, ...)
            if mode and mode:find("w", 1, true) then
                return { write = function() end, close = function() end }
            end
            return realOpen(path, mode, ...)
        end
    end)

    after_each(function()
        io.open = realOpen
    end)

    it("runs requests in arrival order through one queued task", function()
        local tasks = {}
        local binds = {}
        local order = {}
        local responses = {}
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                table.insert(order, args.sequence)
                return { sequence = args.sequence }
            end,
        }
        local mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = {
            send = function(_, payload)
                table.insert(responses, payload)
            end,
        }

        local requestBind = binds[1]
        local function request(id, sequence)
            return '{"id":"' .. id .. '","action":"list_collections",' ..
                '"params":{"sequence":' .. sequence .. '},' ..
                '"hello":"' .. state.token .. '"}'
        end
        requestBind.onMessage(nil, request("first", 1))
        requestBind.onMessage(nil, request("second", 2))

        assert.are.equal(1, #tasks)
        tasks[1]()

        assert.are.same({ 1, 2 }, order)
        assert.are.equal(2, #responses)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("finalizes a failed response and continues with the next request", function()
        local tasks = {}
        local binds = {}
        local order = {}
        local sendCount = 0
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                table.insert(order, args.sequence)
                return { sequence = args.sequence }
            end,
        }
        local mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = {
            send = function()
                sendCount = sendCount + 1
                if sendCount == 1 then error("response unavailable") end
            end,
        }

        local requestBind = binds[1]
        local function request(id, sequence)
            return '{"id":"' .. id .. '","action":"list_collections",' ..
                '"params":{"sequence":' .. sequence .. '},' ..
                '"hello":"' .. state.token .. '"}'
        end
        requestBind.onMessage(nil, request("first", 1))
        requestBind.onMessage(nil, request("second", 2))

        assert.are.equal(1, #tasks)
        tasks[1]()

        assert.are.same({ 1, 2 }, order)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("finalizes a handler error and continues with the next request", function()
        local tasks = {}
        local binds = {}
        local responses = {}
        local callCount = 0
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                callCount = callCount + 1
                if callCount == 1 then error("catalog unavailable") end
                return { sequence = args.sequence }
            end,
        }
        local mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = {
            send = function(_, payload)
                table.insert(responses, payload)
            end,
        }

        local requestBind = binds[1]
        local function request(id, sequence)
            return '{"id":"' .. id .. '","action":"list_collections",' ..
                '"params":{"sequence":' .. sequence .. '},' ..
                '"hello":"' .. state.token .. '"}'
        end
        requestBind.onMessage(nil, request("first", 1))
        requestBind.onMessage(nil, request("second", 2))

        assert.are.equal(1, #tasks)
        tasks[1]()

        assert.are.equal(2, callCount)
        assert.are.equal(2, #responses)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("releases a cancelled worker context before a reload generation accepts future work", function()
        local tasks = {}
        local binds = {}
        local workerCleanups = {}
        local calls = {}
        local mod
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            workerCleanups = workerCleanups,
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                table.insert(calls, args.sequence)
                if args.sequence == 1 then
                    mod.resetForReload()
                    mod.startServer()
                    local state = _G.LightroomMCP_State
                    state.running = true
                    state.sendConnected = true
                    state.responseSocket = { send = function() end }
                    assert.is_not_nil(workerCleanups[1])
                    workerCleanups[1]()
                    workerCleanups[1]() -- cleanup registration must be idempotent
                    binds[3].onMessage(nil, '{"id":"fresh","action":"list_collections",' ..
                        '"params":{"sequence":3},"hello":"' .. state.token .. '"}')
                end
                return { sequence = args.sequence }
            end,
        }
        mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = { send = function() end }
        binds[1].onMessage(nil, '{"id":"old","action":"list_collections",' ..
            '"params":{"sequence":1},"hello":"' .. state.token .. '"}')

        assert.are.equal(1, #tasks)
        tasks[1]()
        assert.are.same({ 1 }, calls)
        assert.are.equal(2, #tasks)
        tasks[2]()

        assert.are.same({ 1, 3 }, calls)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("does not overlap a stopped worker with a new server generation", function()
        local tasks = {}
        local binds = {}
        local calls = {}
        local mod
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                table.insert(calls, args.sequence)
                if args.sequence == 1 then
                    mod.stopServer()
                    mod.startServer()
                    local state = _G.LightroomMCP_State
                    state.running = true
                    state.sendConnected = true
                    state.responseSocket = { send = function() end }
                    -- The new listener exists, but the old worker still owns
                    -- the backend. This request must be rejected and never
                    -- appear as a later task after the owner releases.
                    assert.is_false(state.queueAccepting)
                    local taskCountBeforeReject = #tasks
                    binds[3].onMessage(nil, '{"id":"rejected","action":"list_collections",' ..
                        '"params":{"sequence":99},"hello":"' .. state.token .. '"}')
                    assert.are.equal(taskCountBeforeReject, #tasks)
                end
                return { sequence = args.sequence }
            end,
        }
        mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = { send = function() end }
        local requestBind = binds[1]
        local function request(id, sequence)
            return '{"id":"' .. id .. '","action":"list_collections",' ..
                '"params":{"sequence":' .. sequence .. '},' ..
                '"hello":"' .. state.token .. '"}'
        end
        requestBind.onMessage(nil, request("old", 1))
        requestBind.onMessage(nil, request("stale", 2))

        assert.are.equal(1, #tasks)
        tasks[1]()
        assert.are.same({ 1 }, calls)
        assert.are.equal(1, #tasks)
        assert.is_false(state.queueRunning)
        assert.is_true(state.queueAccepting)

        -- Only a request received after the owner cleanup may be scheduled.
        binds[3].onMessage(nil, '{"id":"fresh","action":"list_collections",' ..
                        '"params":{"sequence":3},"hello":"' .. state.token .. '"}')
        assert.are.equal(2, #tasks)
        tasks[2]()

        assert.are.same({ 1, 3 }, calls)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("waits for an old reset worker to finish before draining the new generation", function()
        local tasks = {}
        local binds = {}
        local calls = {}
        local mod
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function(args)
                table.insert(calls, args.sequence)
                if args.sequence == 1 then
                    mod.resetForReload()
                    mod.startServer()
                    local state = _G.LightroomMCP_State
                    state.running = true
                    state.sendConnected = true
                    state.responseSocket = { send = function() end }
                    error("old generation failed")
                end
                return { sequence = args.sequence }
            end,
        }
        mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = { send = function() end }
        local requestBind = binds[1]
        requestBind.onMessage(nil, '{"id":"old","action":"list_collections",' ..
            '"params":{"sequence":1},"hello":"' .. state.token .. '"}')

        assert.are.equal(1, #tasks)
        tasks[1]()
        assert.are.same({ 1 }, calls)
        assert.are.equal(1, #tasks)
        assert.is_false(state.queueRunning)
        assert.is_true(state.queueAccepting)
        binds[3].onMessage(nil, '{"id":"fresh","action":"list_collections",' ..
            '"params":{"sequence":3},"hello":"' .. state.token .. '"}')
        assert.are.equal(2, #tasks)
        tasks[2]()

        assert.are.same({ 1, 3 }, calls)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("clears queue ownership when a worker cannot be started", function()
        local tasks = {}
        local binds = {}
        installStubs(nil, tasks, {
            runTask = true,
            stopLoopOnSleep = true,
            queueWorkerStartError = "scheduler unavailable",
            cleanups = {},
            capturedBinds = binds,
        })
        package.loaded.JSON = nil
        package.loaded.HandlerCollections = {
            listCollections = function()
                error("must not dispatch after worker start failure")
            end,
        }
        local mod = loadInfoProvider()

        mod.startServer()
        local state = _G.LightroomMCP_State
        state.running = true
        state.sendConnected = true
        state.responseSocket = { send = function() end }
        binds[1].onMessage(nil, '{"id":"failed","action":"list_collections",' ..
            '"params":{},"hello":"' .. state.token .. '"}')

        assert.are.equal(0, #tasks)
        assert.is_false(state.queueRunning)
        assert.is_nil(state.queueWorkerGeneration)
        assert.is_nil(state.queueWorkerQueue)
        assert.are.equal(0, #state.requestQueue)
        assert.are.equal(0, state.inFlightRequests)
    end)

    it("recovers a failed server task start without accepting a queue", function()
        installStubs(nil, nil, { postTaskError = "context unavailable" })
        local mod = loadInfoProvider()

        mod.startServer()

        local state = _G.LightroomMCP_State
        assert.is_false(state.running)
        assert.is_false(state.queueAccepting)
        assert.is_false(state.queueRunning)
        assert.are.equal(0, #state.requestQueue)
    end)
end)
