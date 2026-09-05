import { toast } from "sonner";
import { postBrief } from "./api";
import { useSurvey } from "./store";
import type { Install, Skill } from "./types";

/* Every action that names the agent goes through here, so it is a Brief, never a toast. */
export async function sendAgentBrief(opts: { installId: string; skillId: string; file: string; path: string; text: string; summary: string }): Promise<boolean> {
  const agent = useSurvey.getState().agentName;
  try {
    await postBrief({ installId: opts.installId, skillId: opts.skillId, file: opts.file, path: opts.path, notes: [], text: opts.text });
    toast.success("Brief sent to " + agent + ": " + opts.summary);
    return true;
  } catch {
    try { await navigator.clipboard.writeText(opts.text); toast("The server did not answer. Brief copied; paste it to " + agent + "."); }
    catch { toast.error("The server did not answer and the clipboard is unavailable."); }
    return false;
  }
}

export function reconcileBrief(i: Install, agent: string): { text: string; skill: Skill } {
  const ds = i.skills.filter((s) => s.drift && s.driftDetail);
  const lines: string[] = ["Brief for " + agent + " — from Spellbook", "Install: " + i.name, "Request: reconcile the copies of the skills below so the agent roots agree. Tell me which copy you kept and why.", ""];
  ds.forEach((s, k) => {
    const d = s.driftDetail!;
    lines.push((k + 1) + ". " + s.name);
    d.copies.forEach((c) => lines.push("   " + c.root + "/" + s.id + "  " + c.lines + " lines · " + c.files + " file" + (c.files === 1 ? "" : "s") + (c.updated ? " · updated " + c.updated : "")));
    if (d.changed?.length) lines.push("   differs: " + d.changed.join(", "));
    Object.keys(d.onlyIn || {}).forEach((root) => { if (d.onlyIn[root].length) lines.push("   only in " + root + ": " + d.onlyIn[root].join(", ")); });
    lines.push("");
  });
  return { text: lines.join("\n"), skill: ds[0] || i.skills[0] };
}

export function openInEditorBrief(i: Install, s: Skill, agent: string): string {
  return "Brief for " + agent + " — from Spellbook\nFile: " + s.path + "/SKILL.md\nRequest: open this file in my editor (or show me the path) so I can work on it alongside the tab. Install: " + i.name + ".\n";
}
