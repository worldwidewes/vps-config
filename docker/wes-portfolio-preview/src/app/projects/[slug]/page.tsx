import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Arrow } from "@/components/Arrow";
import { ArchitectureDiagram } from "@/components/ArchitectureDiagram";
import { ProjectVisual } from "@/components/ProjectVisual";
import { SectionLabel } from "@/components/SectionLabel";
import { projectBySlug, projects } from "@/data/projects";

export function generateStaticParams() { return projects.map(({ slug }) => ({ slug })); }

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const project = projectBySlug(slug);
  if (!project) return {};
  return { title: project.title, description: project.description, alternates: { canonical: `/projects/${project.slug}` } };
}

export default async function ProjectPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const project = projectBySlug(slug);
  if (!project) notFound();
  const isBrowserCase = project.slug === "browser-agent";
  return <main id="main-content" className="page-main case-study">
    <section className="section-shell case-hero"><Link className="back-link" href="/projects">← All projects</Link>
      <div className="case-heading"><div><SectionLabel>{project.index} / CASE STUDY</SectionLabel><p className="eyebrow">{project.eyebrow}</p><h1>{project.title}</h1><p className="case-lede">{project.description}</p></div><span className="draft-tag">{project.state}</span></div>
      <ul className="tech-list">{project.technologies.map((tech) => <li key={tech}>{tech}</li>)}</ul><ProjectVisual type={project.visual} large />
      <p className="visual-disclaimer">{isBrowserCase ? "Local interface study shown with sample values. This is not a live product screenshot." : "Illustrative concept visual. Replace with verified project media before launch."}</p>
    </section>
    <section className="section-shell case-grid-section"><div className="case-section-grid"><CaseBlock index="01" title="The problem" text={project.problem} /><CaseBlock index="02" title="Constraints" items={project.constraints} /><CaseBlock index="03" title="Approach" text={project.approach} /></div></section>
    <section className="section-shell case-section"><SectionLabel>04 / ARCHITECTURE</SectionLabel><h2>How the system fits together.</h2>{isBrowserCase ? <><p>Illustrative flow for a human-reviewed browser-agent concept; implementation details require owner verification.</p><ArchitectureDiagram /></> : <div className="architecture-placeholder"><span className="draft-tag">DIAGRAM PENDING</span><p>A project-specific architecture diagram has not been supplied. Add a verified system map before launch.</p></div>}</section>
    {isBrowserCase && <section className="section-shell case-section"><SectionLabel>06 / INTERFACE STUDY</SectionLabel><h2>Keep the activity visible.</h2><p>A locally constructed interface concept uses sample content only. It is here to communicate hierarchy and review states—not to imply a finished application.</p><div className="study-caption">BROWSER SESSION / CONCEPT 01 <span>STATIC UI STUDY · NOT INTERACTIVE</span></div><ProjectVisual type="browser" large /></section>}
    <section className="section-shell case-grid-section"><div className="case-section-grid"><CaseBlock index="04" title="Key decisions" items={project.decisions} /><CaseBlock index="05" title="Result" text={project.result} draft={!isBrowserCase} /><CaseBlock index="06" title="Lessons learned" items={project.lessons} /></div></section>
    <section className="section-shell case-links"><div><SectionLabel>CONTINUE EXPLORING</SectionLabel><h2>Related links</h2></div><div className="case-link-list"><span className="unavailable-link">{project.liveLabel} <span>Not configured</span></span><span className="unavailable-link">{project.sourceLabel} <span>Not configured</span></span><span className="unavailable-link">{project.setupLabel} <span>Not configured</span></span></div><Link className="text-link" href="/projects">More selected projects <Arrow /></Link></section>
  </main>;
}

function CaseBlock({ index, title, text, items, draft = false }: { index: string; title: string; text?: string; items?: string[]; draft?: boolean }) {
  return <section className="case-block"><span className="case-block-index">{index} /</span><div><h2>{title}{draft && <span className="inline-draft"> DRAFT</span>}</h2>{text && <p>{text}</p>}{items && <ul>{items.map((item) => <li key={item}>{item}</li>)}</ul>}</div></section>;
}
