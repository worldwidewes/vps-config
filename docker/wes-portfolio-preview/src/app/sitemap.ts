import type { MetadataRoute } from "next";
import { projects } from "@/data/projects";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = (process.env.NEXT_PUBLIC_SITE_URL ?? "https://weschance.com").replace(/\/$/, "");
  const routes = ["", "/projects", "/resume", "/lab", ...projects.map(({ slug }) => `/projects/${slug}`)];
  return routes.map((route) => ({ url: `${base}${route}`, changeFrequency: route === "" ? "monthly" : "yearly", priority: route === "" ? 1 : 0.7 }));
}
