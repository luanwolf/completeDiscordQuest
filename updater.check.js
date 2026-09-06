import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const native = readFileSync(new URL("./native.ts", import.meta.url), "utf8");
const install = readFileSync(new URL("./install.ps1", import.meta.url), "utf8");
const settings = readFileSync(new URL("./settings.ts", import.meta.url), "utf8");
const index = readFileSync(new URL("./index.tsx", import.meta.url), "utf8");

assert.match(native, /export async function hasUpdate/);
assert.match(native, /export function applyUpdate/);
assert.match(native, /api\.github\.com\/repos\/luanwolf\/completeDiscordQuest\/commits\/main/);
assert.match(native, /installed-sha\.txt/);
assert.match(native, /vencord-root\.txt/);
assert.match(native, /CDQ_YES/);
assert.match(native, /-WindowStyle", "Hidden"/);

assert.match(install, /installed-sha\.txt/);
assert.match(install, /vencord-root\.txt/);
assert.match(install, /ja esta na versao do GitHub/);
assert.match(install, /RepoUpdated/);

assert.match(settings, /autoUpdate:/);
assert.match(index, /maybeAutoUpdate/);
assert.match(index, /pluginHelpers\?\.CompleteDiscordQuest/);

function needsUpdate(local, remote) {
    return Boolean(remote) && Boolean(local) && remote !== local;
}
assert.equal(needsUpdate("", "abc"), false);
assert.equal(needsUpdate("abc", "abc"), false);
assert.equal(needsUpdate("abc", "def"), true);

console.log("updater.check.js ok");
