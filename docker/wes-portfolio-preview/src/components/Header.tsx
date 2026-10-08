import Link from "next/link";

const links = [
  { href: "/projects", label: "Projects" }, { href: "/resume", label: "Résumé" },
  { href: "/lab", label: "Lab" }, { href: "/#contact", label: "Contact" },
];

export function Header() {
  return <header className="site-header"><div className="header-inner">
    <Link className="wordmark" href="/" aria-label="Wes home">WES<span>.</span></Link>
    <nav aria-label="Main navigation" className="main-nav">{links.map((link) => <Link key={link.href} href={link.href}>{link.label}</Link>)}</nav>
    <span className="header-location"><span className="status-dot" /> San Diego, CA</span>
  </div></header>;
}
