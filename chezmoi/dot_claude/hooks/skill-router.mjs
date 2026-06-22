#!/usr/bin/env node
// Thin-session: UserPromptSubmit hook — always-on GraphiFy auto-routing.
//
// Most local skills are hidden from the model's listing (skillOverrides=
// user-invocable-only). To keep them reachable, on every SUBSTANTIVE prompt this
// runs the local capability router and injects the top-5 candidates as context,
// so the model can Read the right SKILL.md without ever seeing 1400 names.
//
// Pure-local (node + a JSON index) → ~0 model tokens to produce; only the short
// ranked list enters context. Guarded (skips tiny / slash / confirmation prompts)
// and FAIL-OPEN (any error or slowness → emit nothing, never block the prompt).
import { execFileSync } from "node:child_process";
import path from "node:path";

const HOME = process.env.HOME;
const ROUTER = path.join(HOME, ".agents/registry/scripts/route-skills.mjs");
const LIMIT = 5;
const TIMEOUT_MS = 3500;
const MIN_LEN = 10;

// Standalone confirmations / acks (RU+EN) — never worth routing.
const CONFIRM = /^(да|нет|неа|ок(ей)?|ага|угу|ладно|спс|спасибо|готово|понятно|продолжай|дальше|далее|стоп|ok(ay)?|y(es|ep|up)?|no(pe)?|nah|k|thx|thanks|sure|go|go on|next|done|stop|yeah)[\s!.…)?]*$/iu;

function emit(additionalContext) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext },
    }),
  );
}

let input = "";
process.stdin.on("data", (c) => (input += c));
process.stdin.on("end", () => {
  try {
    const prompt = (JSON.parse(input).prompt || "").trim();

    // Guards — skip cheaply, emit nothing.
    if (prompt.length < MIN_LEN) return;
    if (prompt.startsWith("/")) return; // slash command
    if (CONFIRM.test(prompt)) return; // ack / confirmation

    let parsed;
    try {
      const out = execFileSync(process.execPath, [ROUTER, prompt, "--limit", String(LIMIT), "--json"], {
        encoding: "utf8",
        timeout: TIMEOUT_MS,
        stdio: ["ignore", "pipe", "ignore"],
      });
      parsed = JSON.parse(out);
    } catch {
      return; // router missing / slow / error → fail open
    }

    const results = (parsed.results || []).filter((r) => r && r.path);
    if (!results.length) return;

    const lines = results.map((r, i) => {
      const name = r.name || r.id || "?";
      const score = r.route_score ?? r.score ?? "?";
      const desc = (r.description || "").replace(/\s+/g, " ").trim().slice(0, 70);
      const rel = r.path.replace(HOME, "~");
      return `${i + 1}. ${name} (score ${score}) — ${rel}${desc ? `\n   ${desc}` : ""}`;
    });

    emit(
      "GraphiFy skill candidates for this task (auto-routed, local — most skills are hidden by design, this is how you find them):\n" +
        lines.join("\n") +
        "\nIf one clearly fits, Read its SKILL.md and follow it (or hand it to a subagent); ignore the rest and do NOT load other skills. If none fit, just proceed without a skill.",
    );
  } catch {
    // Silent fail — never block a prompt.
  }
});
