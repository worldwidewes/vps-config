import Link from "next/link";
import { Arrow } from "@/components/Arrow";
import { ProjectVisual } from "@/components/ProjectVisual";
import { ProjectCard } from "@/components/ProjectCard";
import { SectionLabel } from "@/components/SectionLabel";
import { StatusList } from "@/components/StatusList";
import { capabilities } from "@/data/site";
import { projects } from "@/data/projects";

export default function HomePage() {
  return <main id="main-content">
    <section className="hero section-shell">
      <div className="hero-copy"><p className="eyebrow hero-eyebrow"><span className="eyebrow-line" /> INDEPENDENT TECHNICAL BUILDER · SAN DIEGO</p>
        <h1>I build useful systems where <span>AI, software,</span> and real-world hardware meet.</h1>
        <p className="hero-support">Local AI, browser agents, self-hosted tools, and practical projects—designed, tested, and documented by Wes.</p>
        <div className="hero-actions"><Link className="button button-primary" href="#selected-work">View selected projects <Arrow /></Link><Link className="button button-quiet" href="/resume">Résumé <Arrow /></Link></div>
        <div className="hero-status"><span className="status-dot" /><p><strong>Currently experimenting</strong> with visible browser agents and local AI workflows.</p></div>
      </div>
      <div className="hero-art-wrap"><ProjectVisual type="workstation" large /><span className="hero-art-index">SYSTEMS / 001</span></div>
      <a className="scroll-cue" href="#selected-work"><span className="scroll-line" /> Scroll to explore</a>
    </section>
    <section id="selected-work" className="section-shell work-section">
      <div className="section-heading"><div><SectionLabel>01 / SELECTED WORK</SectionLabel><h2>Systems built to be useful.</h2></div><Link className="text-link" href="/projects">All projects <Arrow /></Link></div>
      <div className="featured-projects">{projects.map((project, index) => <ProjectCard key={project.slug} project={project} featured reverse={index % 2 === 1} />)}</div>
    </section>
    <section className="resume-band"><div className="section-shell resume-band-inner">
      <div className="resume-band-heading"><SectionLabel>02 / HOW I WORK</SectionLabel><h2>Experience and<br />capabilities.</h2><p>Curious across the stack, grounded in practical problem solving. Résumé details are being verified before publication.</p><Link className="text-link" href="/resume">Explore capabilities <Arrow /></Link></div>
      <div className="capability-grid">{capabilities.map((item, index) => <div className="capability" key={item.title}><span className="capability-number">0{index + 1}</span><h3>{item.title}</h3><p>{item.items}</p></div>)}</div>
      <div className="timeline-preview"><span className="timeline-dot" /><div><span className="tiny-label">EXPERIENCE TIMELINE</span><p>Draft timeline · verified roles, dates, and credentials to be added by Wes.</p></div><span className="draft-tag">DRAFT</span></div>
    </div></section>
    <section className="section-shell lab-section"><div className="section-heading"><div><SectionLabel>03 / CURRENT LAB</SectionLabel><h2>In progress, by design.</h2></div><Link className="text-link" href="/lab">Visit the lab <Arrow /></Link></div><StatusList /><p className="quiet-note">A manually maintained snapshot of current interests—not a live system monitor.</p></section>
    <section id="contact" className="contact-section"><div className="section-shell contact-inner"><SectionLabel>04 / CONTACT</SectionLabel><h2>Have an interesting AI, automation, or systems problem?</h2><p>Contact details and verified profiles will be added before public launch.</p><div className="contact-actions"><span className="placeholder-link">Email · address to be added</span><span className="placeholder-link">GitHub · profile to be added</span><Link className="text-link" href="/resume">Résumé <Arrow /></Link></div><Link className="button button-outline" href="/resume">View résumé draft <Arrow /></Link></div></section>
  </main>;
}
