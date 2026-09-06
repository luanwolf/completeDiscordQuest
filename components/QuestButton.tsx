/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import "./QuestButton.css";

import { Flex } from "@components/Flex";
import { findByCodeLazy, findComponentByCodeLazy } from "@webpack";
import { Alerts, NavigationRouter, Tooltip, useEffect, useState } from "@webpack/common";

import { listVoiceRoomQuests, readClaimedLog } from "../farm";
import settings from "../settings";
import { QuestsStore } from "../stores";

const QuestIcon = findByCodeLazy("\"M7.5 21.7a8.95");
const TopBarButton = findComponentByCodeLazy("badgePosition", "icon");
const SettingsBarButton = findComponentByCodeLazy("keyboardShortcut", "positionKey");
const CountBadge = findComponentByCodeLazy("renderBadgeCount", "disableColor");

function openQuestHome() {
    NavigationRouter.transitionTo("/quest-home");
}

function questsStatus() {
    const availableQuests = [...QuestsStore.quests.values()];
    return availableQuests.reduce((acc, x) => {
        if (new Date(x.config.expiresAt).getTime() < Date.now()) {
            acc.expired++;
        } else if (x.userStatus?.claimedAt) {
            acc.claimed++;
        } else if (x.userStatus?.completedAt) {
            acc.claimable++;
        } else if (x.userStatus?.enrolledAt) {
            acc.enrolled++;
        } else {
            acc.enrollable++;
        }
        return acc;
    }, { enrollable: 0, enrolled: 0, claimable: 0, claimed: 0, expired: 0 });
}

function QuestOverviewBody() {
    const claimed = readClaimedLog(settings.store.claimedLog);
    const voice = listVoiceRoomQuests([...QuestsStore.quests.values()]);
    return (
        <div className="cdq-overview">
            {voice.length > 0 && (
                <>
                    <div className="cdq-overview-title">Precisa de call</div>
                    {voice.map(v => (
                        <div key={v.name} className="cdq-overview-row cdq-overview-warn">⚠ {v.name} ({v.task})</div>
                    ))}
                </>
            )}
            <div className="cdq-overview-title">Resgatadas pelo plugin</div>
            {claimed.length === 0 ? (
                <div className="cdq-overview-muted">Nenhuma ainda.</div>
            ) : claimed.map(c => (
                <div key={c.id} className="cdq-overview-row">{c.name}</div>
            ))}
        </div>
    );
}

export function openQuestOverview(event?: { preventDefault?: () => void; stopPropagation?: () => void; }) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    Alerts.show({
        title: "CompleteDiscordQuest",
        body: <QuestOverviewBody />,
        confirmText: "Fechar",
    });
}

export function QuestsCount() {
    const [status, setStatus] = useState(questsStatus());

    const checkForNewQuests = () => {
        setStatus(questsStatus());
    };

    useEffect(() => {
        QuestsStore.addChangeListener(checkForNewQuests);
        return () => {
            QuestsStore.removeChangeListener(checkForNewQuests);
        };
    }, []);

    return (
        <Flex flexDirection={"row"} justifyContent={"flex-end"} className={"quest-button-badges"} gap={"5px"}>
            {status.enrollable > 0 && (
                <Tooltip text={"Para aceitar"}>
                    {({ onMouseEnter, onMouseLeave }) => (
                        <CountBadge
                            onMouseEnter={onMouseEnter}
                            onMouseLeave={onMouseLeave}
                            count={status.enrollable}
                            color={"var(--status-danger)"}
                            style={{ color: "var(--background-base-lowest)" }}
                        />
                    )}
                </Tooltip>
            )}
            {status.enrolled > 0 && (
                <Tooltip text={"Em andamento"}>
                    {({ onMouseEnter, onMouseLeave }) => (
                        <CountBadge
                            onMouseEnter={onMouseEnter}
                            onMouseLeave={onMouseLeave}
                            count={status.enrolled}
                            color={"var(--status-warning)"}
                            style={{ color: "var(--background-base-lowest)" }}
                        />
                    )}
                </Tooltip>
            )}
            {status.claimable > 0 && (
                <Tooltip text={"Para resgatar"}>
                    {({ onMouseEnter, onMouseLeave }) => (
                        <CountBadge
                            onMouseEnter={onMouseEnter}
                            onMouseLeave={onMouseLeave}
                            count={status.claimable}
                            color={"var(--status-positive)"}
                            style={{ color: "var(--background-base-lowest)" }}
                        />
                    )}
                </Tooltip>
            )}
            {status.claimed > 0 && (
                <Tooltip text={"Resgatadas"}>
                    {({ onMouseEnter, onMouseLeave }) => (
                        <CountBadge
                            onMouseEnter={onMouseEnter}
                            onMouseLeave={onMouseLeave}
                            count={status.claimed}
                            color={"var(--blurple-50)"}
                            style={{ color: "var(--background-base-lowest)" }}
                        />
                    )}
                </Tooltip>
            )}
        </Flex>
    );
}

export function QuestButton({ type }: { type: "top-bar" | "settings-bar"; }) {
    const [state, setState] = useState(questsStatus());
    const [voice, setVoice] = useState(() => listVoiceRoomQuests([...QuestsStore.quests.values()]));

    const refresh = () => {
        setState(questsStatus());
        setVoice(listVoiceRoomQuests([...QuestsStore.quests.values()]));
    };

    useEffect(() => {
        QuestsStore.addChangeListener(refresh);
        return () => {
            QuestsStore.removeChangeListener(refresh);
        };
    }, []);

    const needsRoom = voice.length > 0;
    const className = needsRoom
        ? "quest-button-needs-room"
        : state.enrollable ? "quest-button-enrollable"
            : state.enrolled ? "quest-button-enrolled"
                : state.claimable ? "quest-button-claimable"
                    : "";
    const tooltip = needsRoom
        ? `Precisa de call: ${voice.map(v => v.name).join(", ")}`
        : state.enrollable ? `${state.enrollable} para aceitar`
            : state.enrolled ? `${state.enrolled} em andamento`
                : state.claimable ? `${state.claimable} para resgatar`
                    : "Missões — botão direito: resgates";
    const showBadge = needsRoom || state.enrollable > 0 || state.enrolled > 0 || state.claimable > 0;

    if (type === "top-bar") {
        return (
            <TopBarButton
                className={className}
                iconClassName={undefined}
                disabled={false}
                showBadge={showBadge}
                badgePosition={"bottom"}
                icon={QuestIcon}
                iconSize={20}
                onClick={openQuestHome}
                onContextMenu={openQuestOverview}
                tooltip={tooltip}
                tooltipPosition={"bottom"}
                hideOnClick={false}
            />
        );
    } else if (type === "settings-bar") {
        return (
            <SettingsBarButton
                tooltipText={tooltip}
                onContextMenu={openQuestOverview}
                onClick={openQuestHome}
                disabled={false}
                icon={undefined}
                className={"quest-button " + className}
            ><TopBarButton
                    className={className}
                    iconClassName={undefined}
                    disabled={false}
                    showBadge={showBadge}
                    badgePosition={"bottom"}
                    icon={QuestIcon}
                    iconSize={20}
                    onClick={openQuestHome}
                    onContextMenu={openQuestOverview}
                    hideOnClick={false}
                /></SettingsBarButton>
        );
    }
}
