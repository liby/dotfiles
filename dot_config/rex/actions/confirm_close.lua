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
-- preference and asset names Rex Beta uses for it. An unanswered alert gives up
-- after 20 seconds, so a forgotten one cannot close the pane long after its
-- program was asked about.
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

-- Commands the server starts get only the system PATH, so name the installed
-- server's CLI.
local cli = os.getenv("HOME") .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"

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
    if idle then
      rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
      return
    end
    local program = "A program"
    if foreground then
      program = (foreground.script or foreground.argv0 or foreground.name):match("[^/]+$")
    end
    -- The server runs a client's keys, actions, and focus changes one at a time
    -- (`rex api describe client.action`), so waiting here would hold the clicks
    -- the app sends during the alert until the pane is gone, and they would then
    -- fail. The alert therefore runs detached, and since the action cannot act
    -- once it has returned, the command itself closes the pane on Close, by the
    -- ID of the one the key was pressed in, because the alert can move focus.
    rex.exec.start({
      "sh", "-c", '[ "$(osascript -l JavaScript -e "$1" "$2")" = Close ] && exec "$3" --autostart=false block close -s "$4" "$5"',
      "sh", alert, program, cli, ctx.session_id, ctx.block_id,
    }, { detach = true })
  end,
}
