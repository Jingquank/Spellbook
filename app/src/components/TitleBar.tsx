import { useState } from "react";
import { Command } from "cmdk";
import { toast } from "sonner";
import { rescan } from "../api";
import { pagesOf, useGroups, useSurvey, useUI, visibleInstalls } from "../store";
import { Icon } from "../icons";
import { Marks } from "./InstallBits";
import { Thumb } from "../thumbs";

export function TitleBar() {
  const survey = useSurvey((s) => s.survey);
  const connected = useSurvey((s) => s.connected);
  const agentName = useSurvey((s) => s.agentName);
  const groups = useGroups();
  const setPage = useUI((u) => u.setPage), sort = useUI((u) => u.sort);
  const [q, setQ] = useState("");
  const [focus, setFocus] = useState(false);
  const [scanning, setScanning] = useState(false);
  if (!survey) return <div id="titlebar"><div className="tb-brand"><Icon name="book" />Spellbook</div></div>;
  const installs = visibleInstalls(survey, groups);
  const pages = pagesOf(installs, sort);
  async function doRescan() {
    setScanning(true);
    try { await rescan(); toast.success("Rescanned the roots."); }
    catch { toast.error("Could not reach the local server to rescan."); }
    finally { setScanning(false); }
  }
  return <div id="titlebar">
    <div className="tb-brand"><Icon name="book" />Spellbook</div>
    <div className="tb-proj"><code title="The project this tab was opened for">{survey.projectPath}</code></div>
    <span className="tb-spacer" />
    <Command label="Find a skill" className="tb-search" loop>
      <Icon name="search" size="sm" />
      <Command.Input value={q} onValueChange={setQ} placeholder="Find a skill" onFocus={() => setFocus(true)} onBlur={() => setTimeout(() => setFocus(false), 120)} onKeyDown={(e) => { if (e.key === "Escape") { setQ(""); (e.target as HTMLInputElement).blur(); } }} />
      {q.trim() && focus && <div className="cmdk-pop"><Command.List>
        <Command.Empty>No skill matches “{q}”.</Command.Empty>
        {pages.map((p, n) => <Command.Item key={p.install.id + "/" + p.skill.id} value={p.skill.name + " " + p.install.name} keywords={[p.skill.description]} onSelect={() => { setPage(n); setQ(""); }}>
          <Thumb install={p.install} size={18} /><span className="n">{p.skill.name}</span><span className="in">{p.install.name}</span>
        </Command.Item>)}
      </Command.List></div>}
    </Command>
    <button type="button" className="btn" title="Read the roots again" disabled={scanning} onClick={doRescan}><Icon name="refresh" size="sm" />{scanning ? "Scanning…" : "Rescan"}</button>
    <div className="tb-conn" title={connected ? "Briefs go to " + agentName + ", which opened this tab" : "The local server is not reachable. Copy Brief still works."}>
      <span className="dot" style={connected ? undefined : { background: "var(--sb-disabled)" }} /><Marks marks={[survey.agent]} /><span>{agentName}</span>{!connected && <span className="off">· offline</span>}
    </div>
  </div>;
}
