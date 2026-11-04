-- Confirm foreground programs even when they do not report activity to Rex.
-- Retire this action and its binding when native confirmation covers them.
local shells = { bash = true, fish = true, sh = true, zsh = true }

-- Use a system alert because Rex's Lua API has no confirmation dialog.
-- Accessory activation brings it in front. Restore Rex only while the alert
-- still owns focus, so another app the user selected stays active.
-- NSRunningApplication returns the bundle icon; load the user's choice from
-- Rex's preference and bundled assets. Time out after 20 seconds to avoid
-- closing a pane based on an old process snapshot.
local alert = [[
ObjC.import("AppKit")
function run(argv) {
  const [message, cli, session, block, server] = argv
  const app = $.NSApplication.sharedApplication
  const rex = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.superlogical.rex").firstObject
  const alert = $.NSAlert.alloc.init
  alert.messageText = "Close Pane?"
  alert.informativeText = message + " Closing the pane will end its program."
  const choice = $.NSUserDefaults.alloc.initWithSuiteName("com.superlogical.rex").stringForKey("Workspace.appIcon").js
  const chosen = choice && $.NSBundle.bundleWithURL(rex.bundleURL).imageForResource("PlainAppIcon" + choice[0].toUpperCase() + choice.slice(1) + "Beta")
  alert.icon = chosen && !chosen.isNil() ? chosen : rex.icon
  alert.addButtonWithTitle("Close")
  alert.addButtonWithTitle("Cancel")
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)
  app.activateIgnoringOtherApps(true)
  app.performSelectorWithObjectAfterDelayInModes("abortModal", $(), 20, $([$.NSModalPanelRunLoopMode]))
  const response = alert.runModal
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
  if (app.isActive) rex.activateWithOptions(0)
}
]]

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
