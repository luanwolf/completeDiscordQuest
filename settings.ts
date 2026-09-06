/*
 * Vencord, a Discord client mod
 * Copyright (c) 2025 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { definePluginSettings } from "@api/Settings";
import { OptionType } from "@utils/types";

export default definePluginSettings({
    hasAcceptedToUsePlugin: {
        type: OptionType.BOOLEAN,
        displayName: "Permitir automação",
        description: "Permitir completar missões automaticamente. Desligue para parar.",
        default: false
    },
    hasSeenConsentWarning: {
        type: OptionType.BOOLEAN,
        description: "Aviso de risco já foi mostrado.",
        default: false,
        hidden: true
    },
    consentArmed: {
        type: OptionType.BOOLEAN,
        description: "Aviso de risco aguardando o primeiro reinício.",
        default: false,
        hidden: true
    },
    acceptQuestsAutomatically: {
        type: OptionType.BOOLEAN,
        displayName: "Aceitar missões sozinho",
        description: "Aceitar missões disponíveis sozinho.",
        default: false
    },
    showQuestsButtonTopBar: {
        type: OptionType.BOOLEAN,
        displayName: "Botão na barra de cima",
        description: "Mostrar o botão de missões na barra de cima.",
        default: true,
        restartNeeded: true
    },
    showQuestsButtonSettingsBar: {
        type: OptionType.BOOLEAN,
        displayName: "Botão no card do usuário",
        description: "Mostrar o botão de missões no card do usuário (mudo, fone, configurações). Botão direito: resgates e missões que precisam de call.",
        default: true,
        restartNeeded: true
    },
    showQuestsButtonBadges: {
        type: OptionType.BOOLEAN,
        displayName: "Contadores no botão",
        description: "Mostrar contadores no botão de missões.",
        default: true
    },
    farmVideos: {
        type: OptionType.BOOLEAN,
        displayName: "Missões de vídeo",
        description: "Completar missões de vídeo.",
        default: true
    },
    farmPlayOnDesktop: {
        type: OptionType.BOOLEAN,
        displayName: "Missões de jogar no app",
        description: "Completar missões de jogar no app.",
        default: true
    },
    farmStreamOnDesktop: {
        type: OptionType.BOOLEAN,
        displayName: "Missões de transmitir",
        description: "Completar missões de transmitir. Ainda precisa de uma call com outra pessoa e transmitir qualquer janela.",
        default: true
    },
    farmPlayActivity: {
        type: OptionType.BOOLEAN,
        displayName: "Missões de atividade",
        description: "Completar missões de atividade.",
        default: true
    },
    claimRewardsAutomatically: {
        type: OptionType.BOOLEAN,
        displayName: "Resgatar recompensas sozinho",
        description: "Resgatar missões já concluídas.",
        default: true
    },
    claimedLog: {
        type: OptionType.STRING,
        description: "Histórico de resgates do plugin.",
        default: "[]",
        hidden: true
    },
    farmRewardCodes: {
        type: OptionType.BOOLEAN,
        displayName: "Recompensa: código",
        description: "Aceitar missões que dão código de resgate.",
        default: true
    },
    farmInGame: {
        type: OptionType.BOOLEAN,
        displayName: "Recompensa: no jogo",
        description: "Aceitar missões que dão recompensa no jogo.",
        default: true
    },
    farmCollectibles: {
        type: OptionType.BOOLEAN,
        displayName: "Recompensa: colecionável",
        description: "Aceitar missões que dão colecionável.",
        default: true
    },
    farmVirtualCurrency: {
        type: OptionType.BOOLEAN,
        displayName: "Recompensa: orbs",
        description: "Aceitar missões que dão orbs.",
        default: true
    },
    farmFractionalPremium: {
        type: OptionType.BOOLEAN,
        displayName: "Recompensa: Nitro fracionado",
        description: "Aceitar missões que dão Nitro fracionado.",
        default: true
    },
});
