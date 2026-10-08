export function Arrow({ diagonal = false }: { diagonal?: boolean }) {
  return <span className="arrow-icon" aria-hidden="true">{diagonal ? "↗" : "→"}</span>;
}
