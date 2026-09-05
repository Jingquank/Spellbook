import type { Survey } from "./types";

export async function getSurvey(): Promise<Survey> {
  const r = await fetch("/api/survey", { cache: "no-store" });
  if (!r.ok) throw new Error("survey " + r.status);
  return r.json();
}

export async function getFile(installId: string, skillId: string, path: string): Promise<{ text: string; mtime: string }> {
  const q = new URLSearchParams({ install: installId, skill: skillId, path });
  const r = await fetch("/api/file?" + q.toString(), { cache: "no-store" });
  if (!r.ok) throw new Error((await r.json().catch(() => ({ error: r.status })) as { error: string }).error);
  return r.json();
}

export interface BriefBody { installId: string; skillId: string; file: string; path: string; notes: { quote: string; line: string | null; text: string }[]; text: string }
export async function postBrief(body: BriefBody): Promise<{ id: string; at: string; delivered: boolean }> {
  const r = await fetch("/api/briefs", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  if (!r.ok) throw new Error("brief " + r.status);
  return r.json();
}

export async function rescan(): Promise<void> { await fetch("/api/rescan", { method: "POST" }); }

export type ServerEvent =
  | { type: "hello"; agent: string; agentName: string; port: number; scanned: string }
  | { type: "changed"; installId: string; skillId: string; file: string; at: string }
  | { type: "brief-taken"; id: string; at: string }
  | { type: "survey"; scanned: string; installs: number }
  | { type: "offline" };

export function subscribe(onEvent: (e: ServerEvent) => void): () => void {
  const es = new EventSource("/api/events");
  const on = (name: string) => es.addEventListener(name, (ev) => { try { onEvent({ type: name, ...JSON.parse((ev as MessageEvent).data) } as ServerEvent); } catch { /* ignore */ } });
  ["hello", "changed", "brief-taken", "survey"].forEach(on);
  es.onerror = () => onEvent({ type: "offline" });
  return () => es.close();
}
