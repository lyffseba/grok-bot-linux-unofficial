"use strict";

/**
 * Electron entry for the Linux port. Sets a stable desktop identity
 * before the official main process starts so Wayland compositors can
 * match the window to grok-bot.desktop.
 */

const { app } = require("electron");
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
  app.on("browser-window-created", (_event, win) => {
    try {
      win.setIcon(icon);
    } catch {
      // setIcon is unavailable on some platforms; ignore
    }
  });
}

require("./dist/electron-main/main.cjs");
