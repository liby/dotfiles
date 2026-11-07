-- Confirm foreground programs even when they do not report activity to Rex.
-- Retire this action and its binding when native confirmation covers them.
local shells = { bash = true, fish = true, sh = true, zsh = true }

-- Rex's Lua API has no confirmation dialog, so osascript shows a system alert.
local alert = [=[
ObjC.import("AppKit")
ObjC.import("QuartzCore")
function run(argv) {
  const [message, cli, session, block, server] = argv
  const app = $.NSApplication.sharedApplication
  const rex = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.superlogical.rex").firstObject
  const alert = $.NSAlert.alloc.init
  alert.messageText = "Close Pane?"
  alert.informativeText = message + " Closing the pane will end its program."
  // NSRunningApplication returns the bundle icon, so load the user's choice
  // from Rex's preference and bundled assets.
  const choice = $.NSUserDefaults.alloc.initWithSuiteName("com.superlogical.rex").stringForKey("Workspace.appIcon").js
  const chosen = choice && $.NSBundle.bundleWithURL(rex.bundleURL).imageForResource("PlainAppIcon" + choice[0].toUpperCase() + choice.slice(1) + "Beta")
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
  // Center on Rex's frontmost window, where Cmd+W was pressed, a little high
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
  // Time out to avoid closing a pane based on an old process snapshot.
  app.performSelectorWithObjectAfterDelayInModes("abortModal", $(), 20, $([$.NSModalPanelRunLoopMode]))
  const response = alert.runModal
  $.NSNotificationCenter.defaultCenter.removeObserver(handler)
  $.NSObject.cancelPreviousPerformRequestsWithTarget(app)
  // The dismissed alert leaves the screen only when the run loop turns, so
  // turn it before blocking on the close or the alert outlives the pane.
  $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1))
  if (response == $.NSAlertFirstButtonReturn) {
    // Close by ID the pane the key was pressed in, which need not have focus by now.
    const close = $.NSTask.alloc.init
    close.executableURL = $.NSURL.fileURLWithPath(cli)
    close.arguments = $(["--autostart=false", ...(server ? ["-S", server] : []), "block", "close", "-s", session, block])
    const stderr = $.NSPipe.pipe
    close.standardError = stderr
    let failure
    if (close.launchAndReturnError(null)) {
      const output = stderr.fileHandleForReading.readDataToEndOfFile
      close.waitUntilExit
      if (close.terminationStatus != 0) {
        failure = $.NSString.alloc.initWithDataEncoding(output, $.NSUTF8StringEncoding).js || "Rex exited with status " + close.terminationStatus + "."
      }
    } else {
      failure = "The Rex command could not be started."
    }
    if (failure) {
      const error = $.NSAlert.alloc.init
      error.messageText = "Could Not Close Pane"
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

-- Cmd+W ends an open alert first, so at most one alert is open and it asks
-- about the latest request.
local pending

rex.action{
  name = "confirm_close",
  title = "Close Pane with Confirmation",
  run = function(ctx)
    if pending and pending:running() then pending:kill() end
    if not ctx.block_id then
      rex.client.queue("client.close")
      return
    end
    local info = rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
    local foreground = info and info.foreground
    -- A shell running a command, such as `sh -c` around a pipeline, also reports
    -- itself, so only a login shell, whose argv0 starts with "-", counts as idle.
    -- A failed lookup asks, because a wrong guess ends a running program.
    local idle = info and (info.last_exit or (foreground and shells[foreground.name] and (foreground.argv0 or ""):sub(1, 1) == "-"))
    if idle then
      assert(rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id }))
      return
    end
    local message = "The pane's program status is unavailable."
    if foreground then
      message = (foreground.script or foreground.argv0 or foreground.name):match("[^/]+$") .. " is still running."
    end
    -- The server runs a client's keys, actions, and focus changes one at a time
    -- (`rex api describe client.action`), so waiting here would hold the clicks
    -- the app sends during the alert until the pane is gone, and they would then
    -- fail. The alert therefore runs detached and closes the pane itself, and
    -- without a shell, so that killing its handle ends the alert. Rex sends the
    -- action's own calls to the server of a pane on another host but not the
    -- alert's CLI, which therefore gets that server for `-S`.
    pending = assert(rex.exec.start({
      "osascript", "-l", "JavaScript", "-e", alert, message, cli, ctx.session_id, ctx.block_id, ctx.server,
    }, { detach = true }))
  end,
}
