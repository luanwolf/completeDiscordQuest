/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { spawn } from "child_process";
import { IpcMainInvokeEvent } from "electron";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { request } from "https";
import { join, resolve } from "path";

function dataDir() {
    return join(process.env.LOCALAPPDATA || "", "completeDiscordQuest");
}

function pluginFromRoot(root: string) {
    return join(root, "src", "userplugins", "completeDiscordQuest");
}

function isPluginDir(dir: string) {
    return existsSync(join(dir, "install.ps1")) && existsSync(join(dir, ".git"));
}

function readSavedRoot(): string | null {
    const file = join(dataDir(), "vencord-root.txt");
    if (!existsSync(file)) return null;
    const root = readFileSync(file, "utf8").trim();
    return root && isPluginDir(pluginFromRoot(root)) ? root : null;
}

function findPluginDir(): string | null {
    const saved = readSavedRoot();
    if (saved) return pluginFromRoot(saved);

    const home = process.env.USERPROFILE || "";
    const hits = [
        join(home, "Vencord"),
        join("D:", "Projetos", "Vencord"),
        join("D:", "Vencord"),
        join(home, "Documents", "Vencord"),
        join(home, "Downloads", "Vencord"),
        join(home, "source", "Vencord"),
        join(home, "src", "Vencord"),
        join(home, "dev", "Vencord"),
        join(home, "Projects", "Vencord"),
        join(home, "git", "Vencord"),
    ];
    for (const root of hits) {
        const plugin = pluginFromRoot(root);
        if (isPluginDir(plugin)) return plugin;
    }
    return null;
}

function vencordRootFromPlugin(plugin: string) {
    return resolve(plugin, "..", "..", "..");
}

function rememberRoot(root: string) {
    const dir = dataDir();
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, "vencord-root.txt"), root);
}

function readGitHead(pluginDir: string): string {
    const gitDir = join(pluginDir, ".git");
    const headFile = join(gitDir, "HEAD");
    if (!existsSync(headFile)) return "";
    const head = readFileSync(headFile, "utf8").trim();
    if (head.startsWith("ref:")) {
        const ref = head.slice(4).trim();
        const refFile = join(gitDir, ...ref.split("/"));
        return existsSync(refFile) ? readFileSync(refFile, "utf8").trim() : "";
    }
    return head;
}

function githubSha(): Promise<string> {
    return new Promise((resolveSha, reject) => {
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
                    resolveSha(JSON.parse(body).sha || "");
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
    const plugin = findPluginDir();
    if (!plugin) return false;
    rememberRoot(vencordRootFromPlugin(plugin));
    const local = readGitHead(plugin);
    if (!local) return false;
    const remote = await githubSha();
    return Boolean(remote) && remote !== local;
}

function spawnEnv(root: string) {
    const home = process.env.USERPROFILE || "";
    const local = process.env.LOCALAPPDATA || join(home, "AppData", "Local");
    const pf = process.env.ProgramFiles || "C:\\Program Files";
    const path = [
        process.env.PATH,
        join(pf, "Git", "cmd"),
        join(pf, "nodejs"),
        join(home, "AppData", "Roaming", "npm"),
        join(local, "completeDiscordQuest", "deps", "pnpm", "node_modules", ".bin"),
    ].filter(Boolean).join(";");
    return { ...process.env, CDQ_YES: "1", VENCORD_DIR: root, PATH: path };
}

export function applyUpdate(_event: IpcMainInvokeEvent) {
    const plugin = findPluginDir();
    if (!plugin) return false;
    const root = vencordRootFromPlugin(plugin);
    rememberRoot(root);
    const script = join(plugin, "install.ps1");
    if (!existsSync(script)) return false;
    const dir = dataDir();
    mkdirSync(dir, { recursive: true });
    const copied = join(dir, "install.ps1");
    copyFileSync(script, copied);
    const ps = join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    const cmd = join(process.env.SystemRoot || "C:\\Windows", "System32", "cmd.exe");
    const log = join(dir, "update.log");
    writeFileSync(log, `[${new Date().toISOString()}] launch\n`, { flag: "a" });
    const launcher = join(dir, "run-update.ps1");
    const q = (s: string) => "'" + s.replace(/'/g, "''") + "'";
    writeFileSync(launcher, [
        `$log = ${q(log)}`,
        "Add-Content -LiteralPath $log -Value (\"[{0}] pid={1} start\" -f (Get-Date).ToString('o'), $PID)",
        "try { Start-Transcript -Path $log -Append | Out-Null } catch { Add-Content -LiteralPath $log -Value (\"[{0}] transcript-fail {1}\" -f (Get-Date).ToString('o'), $_) }",
        "$ErrorActionPreference = 'Stop'",
        "$env:CDQ_YES = '1'",
        `$env:VENCORD_DIR = ${q(root)}`,
        "try {",
        `  Get-Content -LiteralPath ${q(copied)} -Raw -Encoding UTF8 | Invoke-Expression`,
        "} catch {",
        "  Add-Content -LiteralPath $log -Value (\"[{0}] catch {1}\" -f (Get-Date).ToString('o'), $_)",
        "  Write-Host $_",
        "  Write-Host $_.ScriptStackTrace",
        "  throw",
        "} finally { try { Stop-Transcript | Out-Null } catch {} }",
    ].join("\r\n"), "ascii");
    // cmd start escapes Electron's job object so PowerShell stays alive after Discord exits
    const child = spawn(cmd, [
        "/c",
        `start "CDQUpdate" /min "${ps}" -NoProfile -ExecutionPolicy Bypass -File "${launcher}"`
    ], {
        detached: true,
        stdio: "ignore",
        windowsHide: true,
        cwd: dir,
        env: spawnEnv(root)
    });
    child.unref();
    return true;
}
