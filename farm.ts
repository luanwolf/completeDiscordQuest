/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

export const MAX_POST_RETRIES = 8;
export const MAX_RETRY_DELAY_SEC = 300;

export function nextRetryDelay(delay: number, max = MAX_RETRY_DELAY_SEC) {
    return Math.min(delay * 2, max);
}

export function shouldGiveUpRetry(attempts: number, max = MAX_POST_RETRIES) {
    return attempts >= max;
}

export function pickPlayActivityChannel(
    privates: Array<{ id?: string; }>,
    guilds: Array<{ VOCAL?: Array<{ channel?: { id?: string; }; }>; } | null | undefined>
) {
    return privates[0]?.id
        ?? guilds.find(g => g != null && (g.VOCAL?.length ?? 0) > 0)?.VOCAL?.[0]?.channel?.id
        ?? null;
}

export function isClaimable(quest: { userStatus?: { completedAt?: string | null; claimedAt?: string | null; }; }) {
    return Boolean(quest.userStatus?.completedAt && !quest.userStatus?.claimedAt);
}

export type ClaimedEntry = { id: string; name: string; at: string; };

export function getActiveTaskName(quest: {
    config?: { taskConfig?: { tasks?: Record<string, unknown>; }; taskConfigV2?: { tasks?: Record<string, unknown>; }; };
}) {
    const tasks = quest.config?.taskConfig?.tasks || quest.config?.taskConfigV2?.tasks;
    if (!tasks) return null;
    return (["STREAM_ON_DESKTOP", "PLAY_ACTIVITY", "WATCH_VIDEO", "WATCH_VIDEO_ON_MOBILE", "PLAY_ON_DESKTOP"] as const)
        .find(name => tasks[name] != null) ?? null;
}

export function questNeedsVoiceRoom(taskName: string | null) {
    return taskName === "STREAM_ON_DESKTOP" || taskName === "PLAY_ACTIVITY";
}

export function voiceTaskLabel(taskName: string | null) {
    if (taskName === "STREAM_ON_DESKTOP") return "transmitir";
    if (taskName === "PLAY_ACTIVITY") return "atividade";
    return taskName ?? "";
}

export function listVoiceRoomQuests(quests: Array<{
    userStatus?: { enrolledAt?: string | null; completedAt?: string | null; };
    config?: {
        messages?: { questName?: string; };
        taskConfig?: { tasks?: Record<string, unknown>; };
        taskConfigV2?: { tasks?: Record<string, unknown>; };
    };
}>) {
    const out: Array<{ name: string; task: string; }> = [];
    for (const quest of quests) {
        if (!quest.userStatus?.enrolledAt || quest.userStatus?.completedAt) continue;
        const task = getActiveTaskName(quest);
        if (!questNeedsVoiceRoom(task)) continue;
        out.push({
            name: quest.config?.messages?.questName ?? "Missão",
            task: voiceTaskLabel(task)
        });
    }
    return out;
}

export function readClaimedLog(raw: string): ClaimedEntry[] {
    try {
        const parsed = JSON.parse(raw || "[]");
        if (!Array.isArray(parsed)) return [];
        return parsed.filter(e => e && typeof e.id === "string" && typeof e.name === "string");
    } catch {
        return [];
    }
}

export function appendClaimedLog(raw: string, entry: ClaimedEntry, max = 20) {
    const list = readClaimedLog(raw).filter(e => e.id !== entry.id);
    list.unshift(entry);
    return JSON.stringify(list.slice(0, max));
}
