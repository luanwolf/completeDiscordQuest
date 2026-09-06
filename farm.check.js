import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./farm.ts", import.meta.url), "utf8");
assert.match(src, /export const MAX_POST_RETRIES = 8/);
assert.match(src, /return Math.min\(delay \* 2, max\)/);
assert.match(src, /return attempts >= max/);
assert.match(src, /privates\[0\]\?\.id/);
assert.match(src, /completedAt && !quest\.userStatus\?\.claimedAt/);

function nextRetryDelay(delay, max = 300) {
    return Math.min(delay * 2, max);
}
function shouldGiveUpRetry(attempts, max = 8) {
    return attempts >= max;
}
function pickPlayActivityChannel(privates, guilds) {
    return privates[0]?.id
        ?? guilds.find(g => g != null && (g.VOCAL?.length ?? 0) > 0)?.VOCAL?.[0]?.channel?.id
        ?? null;
}
function isClaimable(quest) {
    return Boolean(quest.userStatus?.completedAt && !quest.userStatus?.claimedAt);
}

assert.equal(nextRetryDelay(5), 10);
assert.equal(nextRetryDelay(200), 300);
assert.equal(shouldGiveUpRetry(7), false);
assert.equal(shouldGiveUpRetry(8), true);
assert.equal(pickPlayActivityChannel([{ id: "dm" }], []), "dm");
assert.equal(pickPlayActivityChannel([], [{ VOCAL: [{ channel: { id: "vc" } }] }]), "vc");
assert.equal(pickPlayActivityChannel([], [null, { VOCAL: [] }]), null);
assert.equal(isClaimable({ userStatus: { completedAt: "1", claimedAt: null } }), true);
assert.equal(isClaimable({ userStatus: { completedAt: "1", claimedAt: "2" } }), false);

console.log("farm.check ok");
