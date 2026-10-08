import { labItems } from "@/data/site";

export function StatusList() {
  return <div className="status-list">{labItems.map((item) => <div className="status-row" key={item.index}>
    <span className="status-number">{item.index}</span><span className="status-word">{item.status}</span><span className="status-detail">{item.detail}</span><span className="status-indicator" aria-hidden="true">●</span>
  </div>)}</div>;
}
