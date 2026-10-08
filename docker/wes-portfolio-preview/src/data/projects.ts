export type Project = {
  slug: string; title: string; shortTitle: string; description: string; technologies: string[];
  index: string; eyebrow: string; state: "Prototype study" | "Draft case study";
  visual: "workstation" | "browser" | "lab" | "trailer"; problem: string;
  constraints: string[]; approach: string; decisions: string[]; result: string; lessons: string[];
  setupLabel: string; liveLabel: string; sourceLabel: string;
};

export const projects: Project[] = [
  {
    slug: "local-ai-workstation", title: "Local AI Workstation", shortTitle: "Local AI",
    description: "A private Apple Silicon environment for testing useful language models, tool calling, memory usage, quantization, and inference performance.",
    technologies: ["MLX", "Ollama", "Open WebUI", "Python"], index: "01", eyebrow: "LOCAL INFERENCE / PRIVATE BY DESIGN", state: "Draft case study", visual: "workstation",
    problem: "Add the specific workflow this workstation was built to support, and what made existing hosted tools unsuitable.",
    constraints: ["Confirm hardware and memory configuration", "Add verified model and evaluation details", "Keep private data local where required"],
    approach: "Document the actual model-serving setup, evaluation workflow, and how MLX, Ollama, and Open WebUI are used together.",
    decisions: ["Record model versions and quantization settings", "Separate measured behavior from subjective observations", "Do not publish private prompts or data"],
    result: "Verified results and model comparisons have not yet been supplied.",
    lessons: ["Add observed trade-offs from real model runs", "Include reproducible setup steps once verified"],
    setupLabel: "Setup notes not yet supplied", liveLabel: "Live workstation link not configured", sourceLabel: "Source repository not configured",
  },
  {
    slug: "browser-agent", title: "Visible Browser Agent", shortTitle: "Browser Agent",
    description: "An AI agent that navigates the web while the user watches, intervenes, and reviews each important action.",
    technologies: ["Playwright", "MCP", "OpenCode", "Browser Automation"], index: "02", eyebrow: "HUMAN-IN-THE-LOOP / BROWSER AUTOMATION", state: "Prototype study", visual: "browser",
    problem: "Browser automation can be difficult to trust when actions happen out of sight. This concept explores a visible flow where a person can follow, pause, and review an agent's work.",
    constraints: ["Keep the browser state visible to the operator", "Make confirmation and intervention points understandable", "Treat the interface shown here as a local concept study, not a verified live application"],
    approach: "The illustrative flow separates a task request, a visible browser session, and an action review. A human remains in the loop for consequential steps; the diagram and screen below are interface studies, not production telemetry.",
    decisions: ["Represent agent activity as readable steps instead of fake code", "Keep the operator in control of pause and approval", "Label sample content so it cannot be mistaken for a live session"],
    result: "This page demonstrates a prototype direction only. No production deployment, measured outcome, or verified automation result has been provided.",
    lessons: ["Define which actions always require approval", "Test recovery and error states with real workflows", "Publish only verified screenshots and outcomes"],
    setupLabel: "Prototype setup details pending verification", liveLabel: "Prototype URL not configured", sourceLabel: "Source repository not configured",
  },
  {
    slug: "self-hosted-ai-lab", title: "Self-Hosted AI Lab", shortTitle: "AI Lab",
    description: "A collection of isolated services for AI experiments, automation, network tools, media, and remote access.",
    technologies: ["Docker", "Linux", "Tailscale", "n8n"], index: "03", eyebrow: "SELF-HOSTED / ISOLATED SERVICES", state: "Draft case study", visual: "lab",
    problem: "Add the verified problem statement and the services or workflows that motivated this lab.",
    constraints: ["Keep service boundaries explicit", "Avoid exposing internal-only services publicly", "Document backups and recovery steps"],
    approach: "Replace this draft with the actual service topology, deployment conventions, and operational practices.",
    decisions: ["Keep app data and secrets out of public source control", "Use a reverse proxy for public services", "Document which services are private"],
    result: "Operational results and service details have not yet been supplied for publication.",
    lessons: ["Add verified deployment and recovery learnings", "Do not present a static diagram as live system health"],
    setupLabel: "Architecture notes not yet supplied", liveLabel: "Live service links not configured", sourceLabel: "Source repository not configured",
  },
  {
    slug: "trailer-systems-project", title: "Trailer Systems Project", shortTitle: "Trailer Systems",
    description: "Practical electrical, battery, solar, networking, and documentation work for a travel-trailer platform.",
    technologies: ["Solar", "LiFePO4", "CAD", "Networking"], index: "04", eyebrow: "PHYSICAL SYSTEMS / DOCUMENTED BUILD", state: "Draft case study", visual: "trailer",
    problem: "Add the actual project goals and the systems that needed to work together.",
    constraints: ["Verify all electrical specifications before publishing", "Distinguish planned work from completed work", "Include safety review where appropriate"],
    approach: "Document the verified design, implementation sequence, and test approach for the trailer systems.",
    decisions: ["Keep diagrams consistent with the final build", "Identify assumptions and safety-critical ratings", "Link only to real build documentation"],
    result: "Build status and measured results have not yet been supplied for publication.",
    lessons: ["Add practical observations from the finished work", "Verify all dimensions and equipment details"],
    setupLabel: "Build log not yet supplied", liveLabel: "Build log link not configured", sourceLabel: "Source repository not configured",
  },
];

export const projectBySlug = (slug: string) => projects.find((project) => project.slug === slug);
