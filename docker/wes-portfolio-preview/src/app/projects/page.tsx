import type { Metadata } from "next";
import { SectionLabel } from "@/components/SectionLabel";
import { ProjectCard } from "@/components/ProjectCard";
import { projects } from "@/data/projects";

export const metadata: Metadata = { title: "Selected Projects", description: "Selected work across local AI, browser agents, self-hosted systems, and practical hardware.", alternates: { canonical: "/projects" } };

export default function ProjectsPage() {
  return <main id="main-content" className="page-main"><section className="section-shell page-intro"><SectionLabel>PORTFOLIO / 01—04</SectionLabel><h1>Selected projects.</h1><p>Four systems problems, explored across software, infrastructure, and the physical world. Unverified details are clearly marked as drafts.</p></section><section className="section-shell project-index-list" aria-label="Selected projects">{projects.map((project, index) => <ProjectCard key={project.slug} project={project} reverse={index % 2 === 1} />)}</section></main>;
}
