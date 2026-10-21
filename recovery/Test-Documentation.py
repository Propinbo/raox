"""Check local documentation without network access or third-party packages."""
import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.ids = set()
        self.remote_embeds = []
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append(attrs[key])
                if (key == "src" or attrs.get("rel") == "stylesheet") and urlsplit(attrs[key]).scheme in ("http", "https"):
                    self.remote_embeds.append(attrs[key])
        for key in ("id", "name"):
            if attrs.get(key):
                self.ids.add(attrs[key])


def check(root):
    html = {p: Page(p.read_text(encoding="utf-8-sig")) for p in (root / "docs").rglob("*.html")}
    links = [(p, url) for p, page in html.items() for url in page.links]
    for p in (root / "docs/styles").glob("*.css"):
        links.extend((p, url) for url in re.findall(r'url\([\'\"]?([^\)\'\"]+)', p.read_text(encoding="utf-8")))
    # Sidebar paths are resolved against the viewed HTML document, not the JS file.
    script = (root / "docs/scripts/table_of_contents.js").read_text(encoding="utf-8")
    sidebar = re.findall(r'"href"\s*:\s*"([^"]+)"', script) + re.findall(r'href="([^"]+)"', script)
    for p in html:
        if "table_of_contents.js" in p.read_text(encoding="utf-8-sig"):
            links.extend((p, url) for url in sidebar)
    markdown = [root / p for p in ("README.md", "build-with-maven.md", "docs/development.md", "docs/history/README-legacy.md", "docs/history/build-legacy.md", "recovery/ROADMAP.md", "recovery/STATE.md", "recovery/STAGE6.md")]
    for p in markdown:
        if p.exists():
            source = re.sub(r"```.*?```", "", p.read_text(encoding="utf-8-sig"), flags=re.S)
            links.extend((p, u.strip("<>")) for u in re.findall(r"\[[^\]]*\]\(([^)]+)\)", source))
    errors, external = [], set()
    for p, page in html.items():
        errors.extend(f"{p.relative_to(root)}: offline help embeds remote resource {url}" for url in page.remote_embeds)
    local = 0
    for source, url in links:
        parts = urlsplit(url)
        if parts.scheme or parts.netloc:
            external.add(url)
            continue
        local += 1
        target = ((root if parts.path.startswith("/") else source.parent) / unquote(parts.path).lstrip("/")).resolve() if parts.path else source
        if not target.is_relative_to(root) or not target.exists():
            errors.append(f"{source.relative_to(root)}: missing {url}")
        elif parts.fragment and target in html and unquote(parts.fragment) not in html[target].ids:
            errors.append(f"{source.relative_to(root)}: missing anchor {url}")
    # Every retained help page must be directly reachable from the static landing page.
    index = root / "docs/index.html"
    if index not in html:
        errors.append("docs/index.html is missing")
    else:
        reachable = {(index.parent / urlsplit(u).path).resolve() for u in html[index].links if not urlsplit(u).scheme}
        for p in html:
            if p != index and p not in reachable:
                errors.append(f"docs/index.html: page not listed: {p.relative_to(root)}")
    return {"html_pages": len(html), "local_references_checked": local,
            "external_references_not_checked": sorted(external), "errors": errors}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = check(args.root.resolve())
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True, indent=2))
    raise SystemExit(bool(report["errors"]))
