/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { spawn } from "child_process";
import { IpcMainInvokeEvent } from "electron";
import { existsSync, readFileSync } from "fs";
import { request } from "https";
import { join } from "path";

function dataDir() {
    return join(process.env.LOCALAPPDATA || "", "completeDiscordQuest");
}

function readRoot(): string | null {
    const file = join(dataDir(), "vencord-root.txt");
    if (!existsSync(file)) return null;
    const root = readFileSync(file, "utf8").trim();
    const plugin = join(root, "src", "userplugins", "completeDiscordQuest", "install.ps1");
    return root && existsSync(plugin) ? root : null;
}

function readInstalledSha(): string {
    const file = join(dataDir(), "installed-sha.txt");
    return existsSync(file) ? readFileSync(file, "utf8").trim() : "";
}

function githubSha(): Promise<string> {
    return new Promise((resolve, reject) => {
        const req = request("https://api.github.com/repos/luanwolf/completeDiscordQuest/commits/main", {
            method: "GET",
            headers: {
                "User-Agent": "completeDiscordQuest-updater",
                Accept: "application/vnd.github+json"
            }
        }, res => {
            let body = "";
            res.on("data", chunk => { body += chunk; });
            res.on("end", () => {
                if ((res.statusCode ?? 0) >= 400) {
                    reject(new Error(`github ${res.statusCode}`));
                    return;
                }
                try {
                    resolve(JSON.parse(body).sha || "");
                } catch (err) {
                    reject(err);
                }
            });
        });
        req.on("error", reject);
        req.end();
    });
}

export async function hasUpdate(_event: IpcMainInvokeEvent) {
    const local = readInstalledSha();
    if (!local || !readRoot()) return false;
    const remote = await githubSha();
    return Boolean(remote) && remote !== local;
}

export function applyUpdate(_event: IpcMainInvokeEvent) {
    const root = readRoot();
    if (!root) return false;
    const script = join(root, "src", "userplugins", "completeDiscordQuest", "install.ps1");
    const ps = join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    const child = spawn(ps, [
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", script,
        "-Yes"
    ], {
        detached: true,
        stdio: "ignore",
        windowsHide: true,
        env: { ...process.env, CDQ_YES: "1", VENCORD_DIR: root }
    });
    child.unref();
    return true;
}
