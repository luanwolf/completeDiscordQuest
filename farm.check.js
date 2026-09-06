import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./farm.ts", import.meta.url), "utf8");
assert.match(src, /export const MAX_POST_RETRIES = 8/);
assert.match(src, /return Math.min\(delay \* 2, max\)/);
assert.match(src, /return attempts >= max/);
assert.match(src, /privates\[0\]\?\.id/);
assert.match(src, /completedAt && !quest\.userStatus\?\.claimedAt/);
assert.match(src, /listVoiceRoomQuests/);
assert.match(src, /appendClaimedLog/);

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

function getActiveTaskName(quest) {
    const tasks = quest.config?.taskConfig?.tasks || quest.config?.taskConfigV2?.tasks;
    if (!tasks) return null;
    return ["STREAM_ON_DESKTOP", "PLAY_ACTIVITY", "WATCH_VIDEO", "WATCH_VIDEO_ON_MOBILE", "PLAY_ON_DESKTOP"]
        .find(name => tasks[name] != null) ?? null;
}
function questNeedsVoiceRoom(taskName) {
    return taskName === "STREAM_ON_DESKTOP" || taskName === "PLAY_ACTIVITY";
}
function listVoiceRoomQuests(quests) {
    return quests.filter(q => q.userStatus?.enrolledAt && !q.userStatus?.completedAt && questNeedsVoiceRoom(getActiveTaskName(q)));
}
function readClaimedLog(raw) {
    try {
        const parsed = JSON.parse(raw || "[]");
        return Array.isArray(parsed) ? parsed.filter(e => e && typeof e.id === "string") : [];
    } catch { return []; }
}
function appendClaimedLog(raw, entry, max = 20) {
    const list = readClaimedLog(raw).filter(e => e.id !== entry.id);
    list.unshift(entry);
    return JSON.stringify(list.slice(0, max));
}

assert.equal(questNeedsVoiceRoom("STREAM_ON_DESKTOP"), true);
assert.equal(questNeedsVoiceRoom("WATCH_VIDEO"), false);
assert.equal(listVoiceRoomQuests([
    { userStatus: { enrolledAt: "1" }, config: { taskConfigV2: { tasks: { STREAM_ON_DESKTOP: {} } }, messages: { questName: "Go Live" } } },
    { userStatus: { enrolledAt: "1", completedAt: "2" }, config: { taskConfigV2: { tasks: { PLAY_ACTIVITY: {} } } } },
]).length, 1);
assert.equal(readClaimedLog("not json").length, 0);
const log = JSON.parse(appendClaimedLog("[]", { id: "1", name: "A", at: "x" }));
assert.equal(log[0].name, "A");

console.log("farm.check ok");
