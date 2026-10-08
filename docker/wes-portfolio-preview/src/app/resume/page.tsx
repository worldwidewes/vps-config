import type { Metadata } from "next";
import Link from "next/link";
import { Arrow } from "@/components/Arrow";
import { SectionLabel } from "@/components/SectionLabel";
import { capabilities } from "@/data/site";

export const metadata: Metadata = { title: "Résumé", description: "Capabilities and experience draft for Wes.", alternates: { canonical: "/resume" } };

export default function ResumePage() {
  return <main id="main-content" className="page-main">
    <section className="section-shell page-intro resume-intro"><SectionLabel>PROFILE / DRAFT</SectionLabel><span className="draft-tag">OWNER REVIEW REQUIRED</span><h1>Capabilities,<br />in practice.</h1><p>This preview outlines areas of work without inventing roles, employers, dates, education, or credentials. Add verified experience before public launch.</p></section>
    <section className="section-shell resume-content"><div className="resume-section-title"><SectionLabel>01 / CAPABILITIES</SectionLabel><h2>A cross-disciplinary toolkit.</h2></div><div className="capability-grid resume-capabilities">{capabilities.map((item, index) => <article className="capability" key={item.title}><span className="capability-number">0{index + 1}</span><h3>{item.title}</h3><p>{item.items}</p></article>)}</div></section>
    <section className="resume-timeline"><div className="section-shell"><SectionLabel>02 / EXPERIENCE</SectionLabel><h2>Experience timeline.</h2><div className="timeline-preview timeline-large"><span className="timeline-dot" /><div><span className="tiny-label">DRAFT · REPLACE WITH VERIFIED CONTENT</span><h3>Independent technical work</h3><p>Role details, dates, projects, and outcomes require owner verification. No employers or credentials are listed in this preview.</p></div><span className="draft-tag">DRAFT</span></div></div></section>
    <section className="section-shell resume-download"><div><SectionLabel>03 / DOWNLOAD</SectionLabel><h2>Résumé file unavailable.</h2><p>A résumé download will be added when Wes supplies an approved document. No empty or placeholder file is served.</p></div><span className="unavailable-link">PDF download · not supplied <span>Unavailable</span></span></section>
    <div className="section-shell resume-bottom-link"><Link href="/#contact" className="text-link">Contact <Arrow /></Link></div>
  </main>;
}
