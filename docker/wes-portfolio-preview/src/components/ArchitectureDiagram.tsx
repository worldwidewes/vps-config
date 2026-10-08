export function ArchitectureDiagram() {
  return <div className="architecture" role="img" aria-label="Concept diagram: operator directs an agent, the agent interacts with a visible browser, and review checkpoints return to the operator">
    <div className="architecture-heading"><span>CONCEPT ARCHITECTURE</span><span>NOT A LIVE SYSTEM DIAGRAM</span></div>
    <div className="architecture-flow"><div className="architecture-node"><span className="architecture-icon">01</span><b>Operator</b><small>Task · review · intervene</small></div><span className="architecture-arrow" aria-hidden="true">→</span><div className="architecture-node architecture-node-accent"><span className="architecture-icon">02</span><b>Agent runtime</b><small>Plan · act · report</small></div><span className="architecture-arrow" aria-hidden="true">→</span><div className="architecture-node"><span className="architecture-icon">03</span><b>Visible browser</b><small>Page · actions · state</small></div></div>
    <div className="architecture-return"><span />Human review loop · approval before consequential actions<span /></div>
  </div>;
}
