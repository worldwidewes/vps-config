import type { Project } from "@/data/projects";

export function ProjectVisual({ type, large = false }: { type: Project["visual"]; large?: boolean }) {
  const label = type === "browser" ? "Illustrative browser-agent interface study" : `${type} systems illustration`;
  return <div className={`project-visual visual-${type}${large ? " visual-large" : ""}`} role="img" aria-label={label}>
    <div className="visual-topline"><span>WES / SYSTEMS STUDY</span><span>FIG. {type === "browser" ? "02" : type === "workstation" ? "01" : type === "lab" ? "03" : "04"}</span></div>
    {type === "browser" ? <BrowserStudy /> : <SystemArtwork type={type} />}
    <div className="visual-caption"><span>CONCEPT VISUAL · SAMPLE CONTENT</span><span className="caption-rule" /></div>
  </div>;
}

function SystemArtwork({ type }: { type: Exclude<Project["visual"], "browser"> }) {
  const nodes = type === "workstation" ? ["LOCAL MODEL", "TOOL USE", "PRIVATE DATA", "EVALUATION"] : type === "lab" ? ["REVERSE PROXY", "APP SERVICES", "PRIVATE NETWORK", "BACKUP"] : ["POWER", "BATTERY", "NETWORK", "FIELD NOTES"];
  return <div className={`system-art system-art-${type}`} aria-hidden="true">
    <div className="art-orbit orbit-one" /><div className="art-orbit orbit-two" />
    <div className="art-core"><span className="core-mark">W</span><span>{type === "workstation" ? "LOCAL" : type === "lab" ? "SELF-HOSTED" : "FIELD SYSTEM"}</span></div>
    {nodes.map((node, i) => <div className={`art-node art-node-${i + 1}`} key={node}><span className="node-dot" />{node}</div>)}
    <svg className="art-connectors" viewBox="0 0 600 420" preserveAspectRatio="none" aria-hidden="true"><path d="M300 210 112 90M300 210 490 95M300 210 110 335M300 210 490 330" /><circle cx="300" cy="210" r="4" /><circle cx="112" cy="90" r="3" /><circle cx="490" cy="95" r="3" /><circle cx="110" cy="335" r="3" /><circle cx="490" cy="330" r="3" /></svg>
  </div>;
}

function BrowserStudy() {
  return <div className="browser-study" aria-hidden="true">
    <div className="browser-sidebar"><div className="study-brand"><span className="study-brand-icon">◎</span><span>VISIBLE<br />AGENT</span></div><div className="study-nav active"><span>⌕</span> Current task</div><div className="study-nav"><span>◷</span> Activity</div><div className="sidebar-bottom"><span className="study-avatar">W</span><span>Operator view</span></div></div>
    <div className="browser-main"><div className="study-toolbar"><span>CONCEPT SESSION / 014</span><span className="study-live"><i /> SAMPLE STATE</span></div>
      <div className="study-task"><span className="tiny-label">TASK REQUEST</span><p>Find the product details and prepare a summary for review.</p></div>
      <div className="fake-browser"><div className="fake-browser-bar"><span>● ● ●</span><span className="fake-url">example.local / product</span><span>•••</span></div>
        <div className="fake-page"><div className="fake-page-nav"><b>FIELDNOTES</b><span>Catalog　 Guides　 About</span></div><div className="fake-product"><div className="fake-product-image"><span>PRODUCT<br />PREVIEW</span></div><div><span className="tiny-label">SAMPLE PAGE</span><h4>Everyday field kit</h4><p>Illustrative content only. Not a live website.</p><span className="fake-button">View details</span></div></div></div>
      </div>
      <div className="study-activity"><span className="activity-check">✓</span><span>Page content ready for operator review</span><span className="activity-time">SAMPLE</span></div>
    </div>
  </div>;
}
