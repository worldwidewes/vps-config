import Link from "next/link";
import type { Project } from "@/data/projects";
import { Arrow } from "@/components/Arrow";
import { ProjectVisual } from "@/components/ProjectVisual";

export function ProjectCard({ project, featured = false, reverse = false }: { project: Project; featured?: boolean; reverse?: boolean }) {
  return <article className={`project-card${featured ? " project-card-featured" : ""}${reverse ? " project-card-reverse" : ""}`}>
    <Link className="project-card-visual-link" href={`/projects/${project.slug}`} aria-label={`Read ${project.title} case study`}><ProjectVisual type={project.visual} /></Link>
    <div className="project-card-copy"><p className="project-index"><span>{project.index}</span> / SELECTED WORK</p><p className="eyebrow">{project.eyebrow}</p>
      <h3><Link href={`/projects/${project.slug}`}>{project.title}</Link></h3><p className="project-description">{project.description}</p>
      <ul className="tech-list" aria-label="Technologies">{project.technologies.map((tech) => <li key={tech}>{tech}</li>)}</ul>
      <Link className="text-link" href={`/projects/${project.slug}`}>View case study <Arrow /></Link>
    </div>
  </article>;
}
