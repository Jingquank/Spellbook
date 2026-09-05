import { useEffect, useState } from "react";
import { toast } from "sonner";
import { getFile, getSurvey, subscribe } from "./api";
import { noteKey, useNotes, usePrefs, useSurvey } from "./store";
import { IconSprite } from "./icons";
import { TitleBar } from "./components/TitleBar";
import { Book } from "./components/Book";
import { useFiles } from "./components/Reader";

const hm = () => { const d = new Date(); return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0"); };

export function App() {
  const survey = useSurvey((s) => s.survey);
  const error = useSurvey((s) => s.error);
  const width = usePrefs((p) => p.width), text = usePrefs((p) => p.text);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => { document.body.dataset.width = width; document.documentElement.style.setProperty("--sb-type-reader-body", text + "px"); }, [width, text]);

  useEffect(() => {
    let live = true;
    useSurvey.getState().setError(null as unknown as string);
    getSurvey().then((s) => { if (live) useSurvey.getState().set(s); }).catch((e) => useSurvey.getState().setError(String(e.message || e)));
    return () => { live = false; };
  }, [attempt]);

  useEffect(() => {
    const off = subscribe(async (ev) => {
      const S = useSurvey.getState();
      if (ev.type === "hello") S.setConnected(true);
      if (ev.type === "offline") S.setConnected(false);
      if (ev.type === "survey") { try { S.set(await getSurvey()); } catch { /* keep the old one */ } }
      if (ev.type === "brief-taken") {
        const N = useNotes.getState();
        Object.keys(N.status).forEach((k) => { const st = N.status[k]; if (st && !st.ok && /Waiting/.test(st.text)) N.setStatus(k, { text: S.agentName + " picked up the Brief at " + hm() + ". Waiting for the edit.", ok: false }); });
      }
      if (ev.type === "changed") {
        const key = noteKey(ev.installId, ev.skillId, ev.file);
        let newText: string | null = null;
        if (ev.file === "SKILL.md") { try { const f = await getFile(ev.installId, ev.skillId, "SKILL.md"); newText = f.text; S.patchSkillMd(ev.installId, ev.skillId, f.text); } catch { /* deleted or unreadable */ } }
        useFiles.getState().bump(ev.installId + "/" + ev.skillId + "#" + ev.file);
        const N = useNotes.getState();
        const sent = (N.notes[key] || []).filter((n) => n.state === "sent");
        if (sent.length) {
          // "applied" only when a quoted passage no longer appears verbatim; otherwise the file merely changed.
          const flat = (newText || "").replace(/\s+/g, " ");
          const touched = newText != null && sent.some((n) => n.quote && !flat.includes(n.quote.replace(/\s+/g, " ").slice(0, 60)));
          N.applied(key, hm(), touched ? "applied" : "file changed");
          N.setStatus(key, { text: ev.file + " changed on disk at " + hm() + ". " + (touched ? "A quoted passage changed." : "Read it to see what changed."), ok: true });
          toast.success(ev.file + " changed on disk · reloaded");
        } else toast(ev.file + " changed on disk · reloaded");
      }
    });
    return () => off();
  }, []);

  return <div id="frame">
    <IconSprite />
    <div id="product">
      <TitleBar />
      <div id="body"><div id="stage">
        {survey ? <Book /> : <div className="boot">{error ? <><span>Spellbook could not load the Survey: {error}</span><button type="button" className="btn" onClick={() => setAttempt((a) => a + 1)}>Try again</button></> : "Scanning the roots…"}</div>}
      </div></div>
    </div>
  </div>;
}
