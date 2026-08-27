"use strict";

/**
 * Electron entry for the Linux port. Sets a stable desktop identity
 * before the official main process starts so Wayland compositors can
 * match the window to grok-bot.desktop.
 */

const { app, BrowserWindow } = require("electron");
const fs = require("fs");
const path = require("path");

app.setName("Grok Bot");
app.commandLine.appendSwitch("class", "grok-bot");
if (typeof app.setDesktopName === "function") {
  app.setDesktopName("grok-bot.desktop");
}

function findIcon() {
  const roots = [
    path.join(__dirname, "dist", "renderer", "assets"),
    path.join(process.resourcesPath || "", "icons"),
    path.join(__dirname),
  ];
  for (const root of roots) {
    if (!fs.existsSync(root)) {
      continue;
    }
    const hit = fs
      .readdirSync(root)
      .find((name) => /^app-icon.*\.png$/i.test(name) || name === "grok-bot.png");
    if (hit) {
      return path.join(root, hit);
    }
  }
  return null;
}

const icon = findIcon();
if (icon) {
  const Original = BrowserWindow;
  function WrappedBrowserWindow(options = {}) {
    if (!options.icon) {
      options = { ...options, icon };
    }
    return new Original(options);
  }
  Object.setPrototypeOf(WrappedBrowserWindow, Original);
  WrappedBrowserWindow.prototype = Original.prototype;
  for (const key of Object.getOwnPropertyNames(Original)) {
    if (key === "length" || key === "name" || key === "prototype") {
      continue;
    }
    try {
      WrappedBrowserWindow[key] = Original[key];
    } catch {
      // ignore read-only statics
    }
  }
  require.cache[require.resolve("electron")].exports.BrowserWindow =
    WrappedBrowserWindow;
}

require("./dist/electron-main/main.cjs");
