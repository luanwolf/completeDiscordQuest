import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./index.tsx", import.meta.url), "utf8");
const button = readFileSync(new URL("./components/QuestButton.tsx", import.meta.url), "utf8");
const css = readFileSync(new URL("./components/QuestButton.css", import.meta.url), "utf8");
const settings = readFileSync(new URL("./settings.ts", import.meta.url), "utf8");

assert.match(src, /\?\"BACK_FORWARD_NAVIGATION\":/);
assert.match(src, /trailing:.\{0,80\}\?\\\{children:\\\[/);
assert.equal(src.split("renderQuestButtonTopBar()").length - 1, 2);
assert.doesNotMatch(src, /PlatformTypes\.WEB/);
assert.doesNotMatch(src, /ShopButton/);
assert.doesNotMatch(button, /ShopButton/);
assert.doesNotMatch(button, /transitionTo\("\/shop"\)/);
assert.match(src, /#\{intl::USER_PROFILE_ACCOUNT_POPOUT_BUTTON_A11Y_LABEL\}/);
assert.match(src, /children:\\\[\(\?=.{0,25}\?accountContainerRef\)/);
assert.match(src, /#\{intl::ACCOUNT_SPEAKING_WHILE_MUTED\}/);
assert.match(src, /panelButtonSeen/);
assert.match(src, /showQuestsButtonSettingsBar = true/);
assert.match(button, /HEADER_BAR_BADGE_BOTTOM/);
assert.doesNotMatch(css, /svg-mask-panel-button/);
assert.match(settings, /panelButtonSeen:/);

console.log("patch.check.js ok");
