import Link from "next/link";

export function Footer() {
  return <footer className="site-footer"><div className="footer-inner">
    <Link className="wordmark" href="/" aria-label="Wes home">WES<span>.</span></Link>
    <p>Independent technical builder · San Diego</p><a href="#top">Back to top <span aria-hidden="true">↑</span></a>
    <small>© {new Date().getFullYear()} Wes</small>
  </div></footer>;
}
