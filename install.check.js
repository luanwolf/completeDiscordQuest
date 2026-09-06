import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./install.ps1", import.meta.url), "utf8");

assert.match(src, /irm https:\/\/raw\.githubusercontent\.com\/luanwolf\/completeDiscordQuest\/main\/install\.ps1 \| iex/);
assert.match(src, /OpenJS\.NodeJS\.LTS/);
assert.match(src, /https:\/\/github\.com\/Vendicated\/Vencord\.git/);
assert.match(src, /src\\userplugins\\\$PluginName/);
assert.match(src, /https:\/\/github\.com\/luanwolf\/completeDiscordQuest\.git/);
assert.match(src, /pnpm.*install.*--frozen-lockfile/s);
assert.match(src, /'build'/);
assert.match(src, /scripts\/runInstaller\.mjs',\s*'--',\s*'--install',\s*'--branch',\s*'auto'/);
assert.match(src, /Nao rode como Administrador/);
assert.match(src, /Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass/);
assert.match(src, /Resolve-Native/);
assert.match(src, /CommandType Application/);
assert.match(src, /"\$Name\.cmd"/);
assert.match(src, /Test-VencordSource/);
assert.match(src, /Find-VencordSource/);
assert.match(src, /Find-CheckoutFromInjection/);
assert.match(src, /reusando pasta existente/);
assert.match(src, /function Show-Banner/);
assert.match(src, /function Tui-Menu/);
assert.match(src, /\[OK\]/);
assert.match(src, /\[\*\]/);
assert.equal((src.match(/\$MinNodeMajor = 22/) || []).length, 1);

console.log("install.check ok");
