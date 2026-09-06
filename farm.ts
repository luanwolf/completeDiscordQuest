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
