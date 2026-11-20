-- Confirm foreground programs even when they do not report activity to Rex.
-- Retire these actions and their bindings when native confirmation covers them.
local shells = { bash = true, fish = true, sh = true, zsh = true }

-- osascript shows a system alert on the Mac where the key was pressed. Rex's
-- own prompt, `rex.ui.pick`, would ask every app connected to the server,
-- including one on another device.
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
  // NSRunningApplication returns the bundle icon, so load the user's choice
  // from Rex's preference and bundled assets.
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
  // Center on Rex's frontmost window, where the key was pressed, a little high
  // because a geometrically centered box looks low. Window-server bounds start
  // at the top of the primary display; AppKit's at its bottom.
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

-- Commands the server starts get only the system PATH, so name the installed
-- server's CLI.
local cli = os.getenv("HOME") .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"

-- A close key ends an open alert first, so at most one alert is open and it
-- asks about the latest request.
local pending

-- What a pane's foreground program is called, or nil when the pane is idle.
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

-- The server runs a client's keys, actions, and focus changes one at a time
-- (`rex api describe client.action`), so waiting here would hold the clicks
-- the app sends during the alert until the target is gone, and they would then
-- fail. The alert therefore runs detached and closes the target itself, by ID
-- because focus can move meanwhile, and without a shell, so that killing its
-- handle ends the alert. Rex sends the action's own calls to the server of a
-- pane on another host but not the alert's CLI, which therefore gets that
-- server for `-S`.
local function ask(ctx, kind, message, ...)
  pending = assert(rex.exec.start({
    "osascript", "-l", "JavaScript", "-e", alert, kind, message, cli, ctx.server or "", ...
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
    local program = running(ctx.block_id)
    if not program then
      assert(rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id }))
      return
    end
    ask(ctx, "Pane", "Still running: " .. program .. ". Closing the pane will end it.",
      "block", "close", "-s", ctx.session_id, ctx.block_id)
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
    local blocks = assert(rex.call("session.list_blocks", { session_id = ctx.session_id })).blocks
    local window_id
    for _, block in ipairs(blocks) do
      if block.block_id == ctx.block_id then window_id = block.window_id end
    end
    local programs = {}
    for _, block in ipairs(blocks) do
      if block.window_id == window_id then
        programs[#programs + 1] = running(block.block_id)
      end
    end
    if #programs == 0 then
      assert(rex.call("session.close_window", { session_id = ctx.session_id, window_id = window_id }))
      return
    end
    ask(ctx, "Tab", "Still running: " .. table.concat(programs, ", ") .. ". Closing the tab will end " .. (#programs == 1 and "it." or "them."),
      "window", "close", "-s", ctx.session_id, window_id)
  end,
}
