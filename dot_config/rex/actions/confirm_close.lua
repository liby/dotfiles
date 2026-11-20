-- Rex's own confirmation skips programs that report no activity to it. Retire
-- these actions and their bindings when it covers them.
local shells = { bash = true, fish = true, sh = true, zsh = true }

-- `rex.ui.pick` would ask every app connected to the server, including one on
-- another device, so osascript shows the alert on the Mac that pressed the key.
local alert = [=[
ObjC.import("AppKit")
ObjC.import("QuartzCore")
function run(argv) {
  const [kind, message, cli, server, ...close] = argv
  const app = $.NSApplication.sharedApplication
  const rex = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.superlogical.rex").firstObject
  const alert = $.NSAlert.alloc.init
  alert.messageText = "Close " + kind + "?"
  alert.informativeText = message
  // `rex.icon` is the bundle icon, not the one the user chose.
  const choice = $.NSUserDefaults.alloc.initWithSuiteName("com.superlogical.rex").stringForKey("Workspace.appIcon").js
  const chosen = choice && $.NSBundle.bundleWithURL(rex.bundleURL).imageForResource("PlainAppIcon" + choice[0].toUpperCase() + choice.slice(1))
  alert.icon = chosen && !chosen.isNil() ? chosen : rex.icon
  alert.addButtonWithTitle("Close")
  alert.addButtonWithTitle("Cancel")
  alert.window.animationBehavior = $.NSWindowAnimationBehaviorNone
  // A newly ordered window shows its first frame opaque even with alphaValue
  // already 0, so order it off-screen before placing it.
  alert.layout
  alert.window.setFrameOrigin($.NSMakePoint(-20000, -20000))
  alert.window.orderFrontRegardless
  alert.window.alphaValue = 0
  // Window-server bounds start at the top of the primary display, AppKit's at
  // its bottom. A geometrically centered box looks low, hence 0.3.
  const size = alert.window.frame.size
  const front = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0)))
    .find(w => w.kCGWindowOwnerPID == rex.processIdentifier && w.kCGWindowLayer == 0)
  if (front) {
    const { X, Y, Width, Height } = front.kCGWindowBounds
    alert.window.setFrameOrigin($.NSMakePoint(
      X + (Width - size.width) / 2,
      $.NSScreen.screens.firstObject.frame.size.height - Y - (Height - size.height) * 0.3 - size.height,
    ))
  } else {
    alert.window.center
  }
  // Accessory activation brings the alert in front.
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)
  app.activateIgnoringOtherApps(true)
  // Escape has failed to reach the alert after it lost focus, even once it was
  // clicked again, so losing focus cancels it.
  ObjC.registerSubclass({
    name: "ConfirmCloseAlert",
    methods: { "resign:": { types: ["void", ["id"]], implementation: () => app.abortModal } },
  })
  const handler = $.ConfirmCloseAlert.alloc.init
  $.NSNotificationCenter.defaultCenter.addObserverSelectorNameObject(handler, "resign:", $.NSApplicationDidResignActiveNotification, $())
  // Keep the fade short, since a click during it already counts as leaving.
  $.NSAnimationContext.beginGrouping
  $.NSAnimationContext.currentContext.duration = 0.2
  $.NSAnimationContext.currentContext.timingFunction = $.CAMediaTimingFunction.functionWithControlPoints(0.23, 1, 0.32, 1)
  alert.window.animator.alphaValue = 1
  $.NSAnimationContext.endGrouping
  // Time out to avoid closing based on an old process snapshot.
  app.performSelectorWithObjectAfterDelayInModes("abortModal", $(), 20, $([$.NSModalPanelRunLoopMode]))
  const response = alert.runModal
  $.NSNotificationCenter.defaultCenter.removeObserver(handler)
  $.NSObject.cancelPreviousPerformRequestsWithTarget(app)
  // The dismissed alert leaves the screen only when the run loop turns, so
  // turn it before blocking on the close or the alert outlives its target.
  $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1))
  if (response == $.NSAlertFirstButtonReturn) {
    const task = $.NSTask.alloc.init
    task.executableURL = $.NSURL.fileURLWithPath(cli)
    task.arguments = $(["--autostart=false", ...(server ? ["-S", server] : []), ...close])
    const stderr = $.NSPipe.pipe
    task.standardError = stderr
    let failure
    if (task.launchAndReturnError(null)) {
      const output = stderr.fileHandleForReading.readDataToEndOfFile
      task.waitUntilExit
      if (task.terminationStatus != 0) {
        failure = $.NSString.alloc.initWithDataEncoding(output, $.NSUTF8StringEncoding).js || "Rex exited with status " + task.terminationStatus + "."
      }
    } else {
      failure = "The Rex command could not be started."
    }
    if (failure) {
      const error = $.NSAlert.alloc.init
      error.messageText = "Could Not Close " + kind
      error.informativeText = failure
      error.icon = alert.icon
      error.addButtonWithTitle("OK")
      error.runModal
    }
  }
}
]=]

-- Commands the server starts get only the system PATH.
local cli = os.getenv("HOME") .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"

-- A superseded alert could still close its target, so a close key ends it.
local pending

local function running(block_id)
  local info = rex.block.call("com.superlogical.terminal", "process", { block_id = block_id })
  local foreground = info and info.foreground
  -- A shell running a command, such as `sh -c` around a pipeline, also reports
  -- itself, so only a login shell, whose argv0 starts with "-", counts as idle.
  if info and (info.last_exit or (foreground and shells[foreground.name] and (foreground.argv0 or ""):sub(1, 1) == "-")) then
    return nil
  end
  -- A failed lookup asks, because a wrong guess ends a running program.
  return foreground and (foreground.script or foreground.argv0 or foreground.name):match("[^/]+$") or "a program of unknown status"
end

local function warning(programs, target)
  local last = #programs
  local sentence
  if last == 1 then
    sentence = programs[1] .. " is still running. Closing the " .. target .. " will end it."
  else
    local names = last > 3 and programs[1] .. ", " .. programs[2] .. ", and " .. last - 2 .. " others"
      or table.concat(programs, ", ", 1, last - 1) .. (last > 2 and "," or "") .. " and " .. programs[last]
    sentence = names .. " are still running. Closing the " .. target .. " will end them."
  end
  -- Program names keep their case; only the unknown-status wording starts a sentence.
  return (sentence:gsub("^a program", "A program"))
end

-- The server runs a client's keys, actions, and focus changes one at a time
-- (`rex api describe client.action`), so waiting for the alert here would hold
-- the app's clicks until the target is gone, and they would then fail. The
-- alert therefore runs detached and makes the same call through the CLI: by ID,
-- because focus can move meanwhile; without a shell, so that killing its handle
-- ends it; and with `-S`, because Rex sends an action's calls to the server of
-- a pane on another host but not the CLI's.
local function confirm(ctx, kind, programs, method, params)
  if #programs == 0 then
    assert(rex.call(method, params))
    return
  end
  pending = assert(rex.exec.start({
    "osascript", "-l", "JavaScript", "-e", alert, kind, warning(programs, kind:lower()), cli, ctx.server or "",
    "api", "call", method, rex.json.encode(params),
  }, { detach = true }))
end

rex.action{
  name = "confirm_close",
  title = "Close Pane with Confirmation",
  run = function(ctx)
    if pending and pending:running() then pending:kill() end
    if not ctx.block_id then
      rex.client.queue("client.close")
      return
    end
    confirm(ctx, "Pane", { running(ctx.block_id) },
      "block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
  end,
}

rex.action{
  name = "confirm_close_tab",
  title = "Close Tab with Confirmation",
  run = function(ctx)
    if pending and pending:running() then pending:kill() end
    if not ctx.block_id then
      rex.client.queue("client.tab.close")
      return
    end
    local window_id = assert(rex.call("session.describe_block", { session_id = ctx.session_id, block_id = ctx.block_id })).block.window_id
    local programs = {}
    for _, block in ipairs(assert(rex.call("session.list_blocks", { session_id = ctx.session_id })).blocks) do
      if block.window_id == window_id then
        programs[#programs + 1] = running(block.block_id)
      end
    end
    confirm(ctx, "Tab", programs,
      "session.close_window", { session_id = ctx.session_id, window_id = window_id })
  end,
}
