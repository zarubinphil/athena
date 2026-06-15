// PostToolUse hook (matcher: Skill). Appends one line per skill invocation.
// Fast, side-effect-only, never throws into the harness. harness=codex.
// Mirrors usage_hook.js (claude) — same log file, same format.
let d = "";
const t = setTimeout(() => process.exit(0), 10000);
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (d += c));
process.stdin.on("end", () => {
  clearTimeout(t);
  try {
    const i = JSON.parse(d || "{}");
    if (i.tool_name !== "Skill") return;
    const ti = i.tool_input || {};
    const sk = ti.skill || ti.command || "";
    if (!sk) return;
    const fs = require("fs");
    const os = require("os");
    const logPath = require("path").join(os.homedir(), ".agents/registry/usage.log");
    const line = new Date().toISOString() + "\tcodex\t" + sk + "\n";
    fs.appendFileSync(logPath, line);
  } catch (e) {
    /* never break the tool pipeline */
  }
});
