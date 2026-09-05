import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Install, Note, Page, Survey } from "./types";

/* ---- preferences: kept in the browser, per device ---- */
export type Register = "prose" | "mono";
interface Prefs { register: Register; width: "focused" | "wide"; text: 14 | 15 | 16; setRegister: (r: Register) => void; setWidth: (w: "focused" | "wide") => void; setText: (t: 14 | 15 | 16) => void }
export const usePrefs = create<Prefs>()(persist((set) => ({
  register: "prose", width: "focused", text: 15,
  setRegister: (register) => set({ register }), setWidth: (width) => set({ width }), setText: (text) => set({ text })
}), { name: "spellbook.prefs" }));

/* ---- group state: names and dismissals for Inferred Installs, per project ---- */
interface Groups { renames: Record<string, string>; dismissed: string[]; rename: (id: string, name: string) => void; dismiss: (id: string) => void; restore: (id: string) => void; reset: () => void }
export const useGroups = create<Groups>()(persist((set) => ({
  renames: {}, dismissed: [],
  rename: (id, name) => set((s) => ({ renames: { ...s.renames, [id]: name } })),
  dismiss: (id) => set((s) => ({ dismissed: s.dismissed.includes(id) ? s.dismissed : [...s.dismissed, id] })),
  restore: (id) => set((s) => { const renames = { ...s.renames }; delete renames[id]; return { renames, dismissed: s.dismissed.filter((x) => x !== id) }; }),
  reset: () => set({ renames: {}, dismissed: [] })
}), { name: "spellbook.groups." + location.pathname }));

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

/* Apply renames and dismissals to the scanned Installs. A dismissed Inferred Install becomes its skills as Loose Skills. */
export function visibleInstalls(survey: Survey | null, groups: { renames: Record<string, string>; dismissed: string[] }): Install[] {
  if (!survey) return [];
  const out: Install[] = [];
  for (const i of survey.installs) {
    if (i.kind === "inferred" && groups.dismissed.includes(i.id)) {
      i.skills.forEach((s) => out.push({ id: "loose-" + s.id, name: s.name, kind: "loose", source: i.source, marks: i.marks, drift: !!s.drift, date: s.date, skills: [s], fromDismissed: i.id }));
      continue;
    }
    if (groups.renames[i.id]) out.push({ ...i, name: groups.renames[i.id], renamed: true, originalName: i.name });
    else out.push(i);
  }
  return out;
}
export function installsIn(installs: Install[], source: "project" | "device"): Install[] { return installs.filter((i) => i.source === source); }
export type Sort = "book" | "name" | "date" | "size";
export function sortInstalls(list: Install[], sort: Sort): Install[] {
  if (sort === "book") return list;
  const c = [...list];
  if (sort === "name") c.sort((a, b) => a.name.localeCompare(b.name));
  if (sort === "date") c.sort((a, b) => ((b.updated || b.date) < (a.updated || a.date) ? -1 : 1));
  if (sort === "size") c.sort((a, b) => (b.skills.length - a.skills.length) || (b.skills.reduce((x, s) => x + s.lines, 0) - a.skills.reduce((x, s) => x + s.lines, 0)));
  return c;
}
/* Pages follow the displayed order, in both Registers. */
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
