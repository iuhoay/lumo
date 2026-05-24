"use strict";

// This extension is now a thin trigger: it hands the selected text to
// Lumo.app via the custom URL scheme. All LLM logic, settings, and the
// result window live in the app (PopClip's JS sandbox can't show a real window).

// Custom-scheme URLs go through LaunchServices, which has a length limit.
// Longer selections are handed off via the clipboard instead.
const MAX_URL_TEXT = 6000;

function trigger(mode, input) {
  const text = input.text || "";
  if (text.trim().length === 0) return;

  // Scheme picks which build to target (release vs dev); see Config.json option.
  const scheme = (popclip.options.scheme || "lumo").trim() || "lumo";

  if (text.length > MAX_URL_TEXT) {
    popclip.copyText(text);
    popclip.openUrl(`${scheme}://translate?mode=${mode}&via=clipboard`);
  } else {
    popclip.openUrl(`${scheme}://translate?mode=${mode}&text=${encodeURIComponent(text)}`);
  }
}

exports.actions = [
  { title: "翻译", icon: "symbol:character.bubble", code: (input) => trigger("translate", input) },
  { title: "润色", icon: "symbol:wand.and.stars", code: (input) => trigger("polish", input) },
  { title: "总结", icon: "symbol:text.append", code: (input) => trigger("summarize", input) },
];
