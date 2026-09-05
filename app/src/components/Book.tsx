import { useEffect, useMemo, useRef } from "react";
import { pagesOf, useGroups, usePrefs, useSurvey, useUI, visibleInstalls } from "../store";
import { Icon } from "../icons";
import { Contents } from "./Contents";
import { Reader } from "./Reader";
import { SettingsNav, SettingsPage } from "./Settings";

/* The spread: contents on the left in the chosen Register, the Reader on the right, Settings as the last page. */
export function Book() {
  const survey = useSurvey((s) => s.survey)!;
  const groups = useGroups();
  const register = usePrefs((p) => p.register);
  const { page, mode, sort, setPage, setMode } = useUI();
  const installs = useMemo(() => visibleInstalls(survey, groups), [survey, groups.renames, groups.dismissed]);
  const pages = useMemo(() => pagesOf(installs, sort), [installs, sort]);
  const N = pages.length;
  const cur = Math.min(page, Math.max(0, N - 1));
  const mountRef = useRef<HTMLDivElement>(null);
  const pageLabel = mode === "settings" ? "Settings · page " + (N + 1) + " of " + (N + 1) : "page " + (cur + 1) + " of " + (N + 1);

  function turn(n: number) { if (n >= N) { setMode("settings"); return; } setPage(Math.max(0, n)); }
  useEffect(() => {
    function keys(e: KeyboardEvent) {
      const t = e.target as HTMLElement; if (t.closest("input, textarea, [contenteditable]") || e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key === "ArrowRight" && mode === "read") turn(cur + 1);
      if (e.key === "ArrowLeft") { if (mode === "settings") setPage(cur); else turn(cur - 1); }
      if (e.key === "Escape" && mode === "settings") setPage(cur);
    }
    document.addEventListener("keydown", keys); return () => document.removeEventListener("keydown", keys);
  }, [cur, mode, N]);
  useEffect(() => { const m = mountRef.current; if (!m) return; m.classList.remove("turn"); void m.offsetWidth; m.classList.add("turn"); }, [cur, mode]);

  const p = pages[cur];
  const sameName = p && p.install.skills.length === 1 && p.install.name === p.skill.name;
  return <div className={"gr bk " + (register === "mono" ? "fo" : "gr2")}>
    <div className="gr-book">
      <section className="gr-page l">
        {mode === "settings" ? <SettingsNav survey={survey} onBack={() => setPage(cur)} />
          : <Contents installs={installs} pages={pages} page={cur} onOpen={setPage} projectPath={survey.projectPath} mono={register === "mono"} />}
      </section>
      <section className="gr-page r">
        {mode === "settings" ? <SettingsPage survey={survey} pageLabel={pageLabel} /> : <>
          <div className="gr-run"><span className="rh">{sameName ? "" : p?.install.name}</span><span className="rh">{p?.skill.name}</span></div>
          <div className="gr-mount" ref={mountRef}>{p ? <Reader key={p.install.id + "/" + p.skill.id} install={p.install} skill={p.skill} mode="main" /> : <div className="empty" style={{ padding: 24 }}>Nothing to read yet. Skills that appear in the roots show up here after a rescan.</div>}</div>
        </>}
        <div className="gr-ft">
          <button type="button" className="btn quiet" disabled={mode === "read" && cur <= 0} onClick={() => (mode === "settings" ? setPage(N - 1) : turn(cur - 1))}>‹ Previous</button>
          <span className="gr-pg tnum">{pageLabel}</span>
          <button type="button" className="btn quiet set" onClick={() => (mode === "settings" ? setPage(cur) : setMode("settings"))}><Icon name="settings" size="sm" />{mode === "settings" ? "Back to reading" : "Settings"}</button>
          <button type="button" className="btn quiet" disabled={mode === "settings"} onClick={() => turn(cur + 1)}>Next ›</button>
        </div>
      </section>
    </div>
  </div>;
}
