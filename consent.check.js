import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./consent.ts", import.meta.url), "utf8");
assert.match(src, /if \(state\.hasSeen\) return state\.hasAccepted \? "farm" : "stop"/);
assert.match(src, /if \(!state\.armed && !state\.hasAccepted\) return "arm"/);
assert.match(src, /return "prompt"/);

function nextConsentAction({ hasAccepted, hasSeen, armed }) {
    if (hasSeen) return hasAccepted ? "farm" : "stop";
    if (!armed && !hasAccepted) return "arm";
    return "prompt";
}

assert.equal(nextConsentAction({ hasAccepted: true, hasSeen: false, armed: false }), "prompt");
assert.equal(nextConsentAction({ hasAccepted: true, hasSeen: true, armed: true }), "farm");
assert.equal(nextConsentAction({ hasAccepted: false, hasSeen: true, armed: true }), "stop");
assert.equal(nextConsentAction({ hasAccepted: false, hasSeen: false, armed: false }), "arm");
assert.equal(nextConsentAction({ hasAccepted: false, hasSeen: false, armed: true }), "prompt");

console.log("consent.check ok");
