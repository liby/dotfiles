#!/usr/bin/env osascript -l JavaScript

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Copy Markdown URL and Title
// @raycast.mode silent
//
// Optional parameters:
// @raycast.packageName Copy Markdown URL and Title
// @raycast.icon 🔗
//
// Documentation:
// @raycast.description Copy URL and title from the current browser as markdown.
// @raycast.author Jakub Chodorowicz
// @raycast.authorURL https://github.com/chodorowicz
// script version 1.1

const systemEvents = Application("System Events");
const frontProcess = systemEvents.processes.whose({ frontmost: true })[0];
const appName = frontProcess.displayedName();
const app = Application.currentApplication();
app.includeStandardAdditions = true;

let url = undefined;
let title = undefined;

const chromiumBrowsers = [
  "Google Chrome",
  "Chromium",
  "Brave Browser",
  "Opera",
  "Vivaldi",
];
const webkitBrowser = ["Safari", "Webkit"];
// Arc fails when trying to run JXA automation on it (📆 2023-07-29)
//  so we're using here traditional systemEvents approach
const theRest = ["Firefox", "Arc"];

if (chromiumBrowsers.includes(appName)) {
  const activeWindow = Application(appName).windows[0];
  const activeTab = activeWindow.activeTab();
  url = activeTab.url();
  title = activeTab.name();
}

// Microsoft Edge doesn't work properly with activeWindow.activeTab()
if (appName === "Microsoft Edge") {
  const activeWindow = Application(appName).windows[0];
  const activeTabIndex = activeWindow.activeTabIndex() - 1;
  const activeTab = activeWindow.tabs[activeTabIndex];
  url = activeTab.url();
  title = activeTab.name();
}

if (webkitBrowser.includes(appName)) {
  url = Application(appName).documents[0].url();
  title = Application(appName).documents[0].name();
}

if (theRest.includes(appName)) {
  systemEvents.keystroke("l", { using: "command down" });
  delay(0.2);
  systemEvents.keystroke("c", { using: "command down" });
  delay(0.2);
  /// escape clear the selection of address bar
  systemEvents.keyCode(53);
  url = app.theClipboard();
  title = frontProcess
    .windows()
    .find((window) => window.attributes.byName("AXMain").value() === true)
    .attributes.byName("AXTitle")
    .value();
}

if (title === undefined && url === undefined) {
  console.log("Could not copy URL or title.");
} else {
  app.setTheClipboardTo(`[${title}](${url})`);
  console.log(`Copied URL and title from ${appName}.`);
}