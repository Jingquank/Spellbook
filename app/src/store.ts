import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Install, Note, Page, Survey } from "./types";

/* ---- preferences: kept in the browser, per device ---- */
interface Prefs { width: "focused" | "wide"; text: 14 | 15 | 16; setWidth: (w: "focused" | "wide") => void; setText: (t: 14 | 15 | 16) => void }
export const usePrefs = create<Prefs>()(persist((set) => ({
  width: "focused", text: 15,
  setWidth: (width) => set({ width }), setText: (text) => set({ text })
}), { name: "spellbook.prefs", version: 1,
  migrate: (value) => { const old = value as Partial<Prefs>; return { width: old.width === "wide" ? "wide" : "focused", text: [14, 15, 16].includes(old.text || 0) ? old.text : 15 }; },
  partialize: ({ width, text }) => ({ width, text })
}));
// Remove the retired browser curation state without interpreting it.
try { for (const key of Object.keys(localStorage)) if (key.startsWith("spellbook.groups.")) localStorage.removeItem(key); } catch { /* storage may be unavailable */ }

/* ---- the Survey, straight from the server ---- */
interface SurveyState { survey: Survey | null; error: string | null; connected: boolean; agentName: string; set: (s: Survey) => void; setError: (e: string | null) => void; setConnected: (c: boolean) => void; patchSkillMd: (installId: string, skillId: string, md: string) => void }
export const useSurvey = create<SurveyState>()((set) => ({
  survey: null, error: null, connected: false, agentName: "the agent",
  set: (survey) => set({ survey, agentName: survey.agentName, error: null }),
  setError: (error) => set({ error }),
  setConnected: (connected) => set({ connected }),
  patchSkillMd: (installId, skillId, md) => set((s) => {
    if (!s.survey) return {};
    const installs = s.survey.installs.map((i) => i.id !== installId ? i : { ...i, skills: i.skills.map((k) => k.id !== skillId ? k : { ...k, md, lines: md.split(/\r?\n/).length }) });
    return { survey: { ...s.survey, installs } };
  })
}));

export function installsIn(installs: Install[], source: "project" | "device"): Install[] { return installs.filter((i) => i.source === source); }
export const installKey = (i: Install) => i.source + ":" + i.id;
export type Sort = "book" | "name" | "date" | "size";
export function sortInstalls(list: Install[], sort: Sort): Install[] {
  if (sort === "book") return list;
  const c = [...list];
  if (sort === "name") c.sort((a, b) => a.name.localeCompare(b.name));
  if (sort === "date") c.sort((a, b) => ((b.updated || b.date) < (a.updated || a.date) ? -1 : 1));
  if (sort === "size") c.sort((a, b) => (b.skills.length - a.skills.length) || (b.skills.reduce((x, s) => x + s.lines, 0) - a.skills.reduce((x, s) => x + s.lines, 0)));
  return c;
}
/* Pages follow the displayed order, for contents and Reader. */
export function pagesOf(installs: Install[], sort: Sort = "book"): Page[] { const out: Page[] = []; (["project", "device"] as const).forEach((src) => sortInstalls(installsIn(installs, src), sort).forEach((i) => i.skills.forEach((s) => out.push({ install: i, skill: s })))); return out; }

/* ---- the book: which page is open ---- */
interface UI { page: number; mode: "read" | "settings"; tab: string; sort: Sort; setPage: (n: number) => void; setMode: (m: "read" | "settings") => void; setTab: (t: string) => void; setSort: (s: Sort) => void }
export const useUI = create<UI>()((set) => ({ page: 0, mode: "read", tab: "SKILL.md", sort: "book", setPage: (page) => set({ page, mode: "read" }), setMode: (mode) => set({ mode }), setTab: (tab) => set({ tab }), setSort: (sort) => set({ sort }) }));

/* ---- Notes, per file ---- */
export type Status = { text: string; ok: boolean } | null;
interface NotesState {
  notes: Record<string, Note[]>; hist: Record<string, { at: string; n: number; label: string }[]>; status: Record<string, Status>; sending: Record<string, boolean>; active: string | null;
  add: (key: string, n: Note) => void; update: (key: string, id: string, patch: Partial<Note>) => void; remove: (key: string, id: string) => void; setActive: (id: string | null) => void;
  markSent: (key: string, at: string) => void; applied: (key: string, at: string, label?: string) => void; setStatus: (key: string, s: Status) => void; setSending: (key: string, v: boolean) => void;
}
export const useNotes = create<NotesState>()((set) => ({
  notes: {}, hist: {}, status: {}, sending: {}, active: null,
  add: (key, n) => set((s) => ({ notes: { ...s.notes, [key]: [...(s.notes[key] || []), n] }, active: n.id })),
  update: (key, id, patch) => set((s) => ({ notes: { ...s.notes, [key]: (s.notes[key] || []).map((n) => n.id === id ? { ...n, ...patch } : n) } })),
  remove: (key, id) => set((s) => ({ notes: { ...s.notes, [key]: (s.notes[key] || []).filter((n) => n.id !== id) } })),
  setActive: (active) => set({ active }),
  markSent: (key, at) => set((s) => ({ notes: { ...s.notes, [key]: (s.notes[key] || []).map((n) => n.state === "draft" && !n.editing ? { ...n, state: "sent", sentAt: at } : n) } })),
  applied: (key, at, label) => set((s) => { const sent = (s.notes[key] || []).filter((n) => n.state === "sent"); if (!sent.length) return {}; return { notes: { ...s.notes, [key]: (s.notes[key] || []).filter((n) => n.state !== "sent") }, hist: { ...s.hist, [key]: [...(s.hist[key] || []), { at, n: sent.length, label: label || "applied" }] } }; }),
  setStatus: (key, st) => set((s) => ({ status: { ...s.status, [key]: st } })),
  setSending: (key, v) => set((s) => ({ sending: { ...s.sending, [key]: v } }))
}));
export const noteKey = (installId: string, skillId: string, file: string) => installId + "/" + skillId + "#" + file;
