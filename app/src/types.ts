export type Mark = "claude-code" | "codex" | "gemini" | "cursor";
export type Kind = "recorded" | "inferred" | "loose" | "plugin";
export type Source = "project" | "device";

export interface DriftDetail {
  copies: { root: string; lines: number; files: number; updated?: string }[];
  changed: string[];
  onlyIn: Record<string, string[]>;
}

export interface Skill {
  id: string;
  name: string;
  description: string;
  frontmatter: Record<string, string>;
  lines: number;
  bytes: number;
  files: string[];
  date: string;
  md?: string;
  path: string;
  real?: string;
  marks: Mark[];
  drift: boolean;
  driftDetail?: DriftDetail | null;
  copies?: string[];
}

export interface Install {
  id: string;
  name: string;
  kind: Kind;
  source: Source;
  marks: Mark[];
  drift: boolean;
  date: string;
  updated?: string;
  version?: string;
  manifest?: string;
  manifests?: string[];
  quiet?: boolean;
  skills: Skill[];
  renamed?: boolean;
  originalName?: string;
  fromDismissed?: string;
}

export interface Root { path: string; exists: boolean; skills: number; note: string }

export interface Survey {
  project: string;
  projectPath: string;
  scanned: string;
  agent: Mark;
  agentName: string;
  installs: Install[];
  roots: Root[];
  port?: number;
}

export interface Note {
  id: string;
  file: string;
  quote: string;
  line: string | null;
  text: string;
  state: "draft" | "sent";
  editing: boolean;
  sentAt?: string;
  range?: Range;
}

export interface Page { install: Install; skill: Skill }

export const AGENT_NAMES: Record<Mark, string> = { "claude-code": "Claude Code", codex: "Codex", gemini: "Gemini", cursor: "Cursor" };
export const SOURCE_NAMES: Record<Source, string> = { project: "From this project", device: "On this device" };
