/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

export type ConsentAction = "farm" | "stop" | "arm" | "prompt";

export function nextConsentAction(state: {
    hasAccepted: boolean;
    hasSeen: boolean;
    armed: boolean;
}): ConsentAction {
    if (state.hasSeen) return state.hasAccepted ? "farm" : "stop";
    if (!state.armed && !state.hasAccepted) return "arm";
    return "prompt";
}
