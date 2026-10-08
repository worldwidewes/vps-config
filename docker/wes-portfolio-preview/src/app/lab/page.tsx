import type { Metadata } from "next";
import { SectionLabel } from "@/components/SectionLabel";
import { StatusList } from "@/components/StatusList";

export const metadata: Metadata = { title: "Current Lab", description: "Current experiments and work-in-progress notes.", alternates: { canonical: "/lab" } };

export default function LabPage() {
  return <main id="main-content" className="page-main"><section className="section-shell page-intro"><SectionLabel>FIELD NOTES / CURRENT</SectionLabel><h1>The current lab.</h1><p>A small, manually maintained view of what is being tested and explored. Status notes are not live telemetry or a health monitor.</p><span className="manual-note"><span className="status-dot" /> MANUALLY MAINTAINED · NOT LIVE</span></section><section className="section-shell lab-page-section"><SectionLabel>ACTIVE THREADS / 04</SectionLabel><StatusList /><div className="lab-note-block"><span className="tiny-label">A NOTE ON STATUS</span><p>These labels describe areas of attention, not delivery promises. Details will be expanded as the underlying work and evidence are ready to share.</p></div></section></main>;
}
