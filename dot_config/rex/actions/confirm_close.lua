-- Rex can neither confirm nor undo closing a pane, which ends its program, so
-- this asks first unless the pane's program has exited or its login shell is
-- in the foreground. Remove it and its binding once Rex can do either; Rex
-- feedback post 1560649600577052752 tracks that.
local shells = { bash = true, fish = true, sh = true, zsh = true }

-- A system alert, because the Rex app can draw a floating layer invisible while
-- it keeps focus (Rex feedback post 1559241103117656144).
-- osascript has no activation policy, so without Accessory the alert opens
-- behind Rex and never gets focus; Rex is reactivated because focus does not
-- reliably return to it when osascript exits. NSRunningApplication reports the
-- bundle icon, so the icon chosen under Rex's App Icon setting is loaded by the
-- preference and asset names Rex Beta uses for it.
local alert = [[
ObjC.import("AppKit")
function run(argv) {
  const app = $.NSApplication.sharedApplication
  const rex = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.superlogical.rex").firstObject
  const alert = $.NSAlert.alloc.init
  alert.messageText = "Close Pane?"
  alert.informativeText = argv[0] + " is still running. If you close the pane the process will be killed."
  const choice = $.NSUserDefaults.alloc.initWithSuiteName("com.superlogical.rex").stringForKey("Workspace.appIcon").js
  const chosen = choice && $.NSBundle.bundleWithURL(rex.bundleURL).imageForResource("PlainAppIcon" + choice[0].toUpperCase() + choice.slice(1) + "Beta")
  alert.icon = chosen && !chosen.isNil() ? chosen : rex.icon
  alert.addButtonWithTitle("Close")
  alert.addButtonWithTitle("Cancel")
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)
  app.activateIgnoringOtherApps(true)
  app.performSelectorWithObjectAfterDelayInModes("abortModal", $(), 20, $([$.NSModalPanelRunLoopMode]))
  const response = alert.runModal
  rex.activateWithOptions(0)
  return response == $.NSAlertFirstButtonReturn ? "Close" : "Cancel"
}
]]

rex.action{
  name = "confirm_close",
  title = "Close, Confirming a Running Program",
  run = function(ctx)
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
    if not idle then
      local program = "A program"
      if foreground then
        program = (foreground.script or foreground.argv0 or foreground.name):match("[^/]+$")
      end
      -- An action has 30 seconds to finish; the alert gives up at 20 and hands
      -- focus back, and the timeout only covers an alert that never returns.
      local reply = rex.exec({ "osascript", "-l", "JavaScript", "-e", alert, program }, { timeout = 25 })
      if not (reply and reply.ok and reply.stdout:match("^Close")) then
        return
      end
    end
    -- Client actions act on whatever the app has focused, which the alert can
    -- change, so close the pane the key was pressed in by its ID.
    rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
  end,
}
