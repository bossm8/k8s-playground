#!/usr/bin/env python3
# Usage: python3 helpers/flux-dep-graph.py [--clusters-dir PATH] [--cluster NAME] [--output html|mermaid|text] [--show-path] [--out-file PATH]
# Setup:  python3 -m venv .venv && .venv/bin/pip install pyyaml pyvis

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml
from pyvis.network import Network

FLUX_API = "kustomize.toolkit.fluxcd.io/v1"

CLUSTER_COLORS = ["#4e79a7", "#f28e2b", "#59a14f", "#e15759", "#76b7b2"]
DANGLING_COLOR = "#e15759"


def collect_kustomizations(clusters_dir: Path, cluster_filter: str | None) -> list[dict]:
    results = []
    for yaml_file in sorted(clusters_dir.rglob("*.yaml")):
        parts = yaml_file.parts
        try:
            clusters_idx = parts.index(clusters_dir.name)
            cluster = parts[clusters_idx + 1]
        except (ValueError, IndexError):
            continue

        if cluster_filter and cluster != cluster_filter:
            continue

        for doc in yaml.safe_load_all(yaml_file.read_text()):
            if not isinstance(doc, dict):
                continue
            if doc.get("apiVersion") != FLUX_API or doc.get("kind") != "Kustomization":
                continue
            meta = doc.get("metadata", {})
            spec = doc.get("spec", {})
            name = meta.get("name", "")
            if not name:
                continue
            depends_on = [
                d["name"] for d in spec.get("dependsOn", [])
                if isinstance(d, dict) and "name" in d
            ]
            results.append({
                "cluster": cluster,
                "name": name,
                "depends_on": depends_on,
                "path": spec.get("path", ""),
                "interval": spec.get("interval", ""),
            })
    return results


def build_graph(kustomizations: list[dict]) -> dict:
    graph: dict[str, list[dict]] = {}
    for ks in kustomizations:
        graph.setdefault(ks["cluster"], []).append(ks)

    for cluster, nodes in graph.items():
        known = {n["name"] for n in nodes}
        for node in nodes:
            for dep in node["depends_on"]:
                if dep not in known:
                    print(f"warning: [{cluster}] '{node['name']}' depends on unknown '{dep}'", file=sys.stderr)

    return graph


def render_html(graph: dict, show_path: bool, out_file: Path | None) -> None:
    net = Network(
        directed=True,
        height="100vh",
        width="100%",
        bgcolor="#1a1a2e",
        font_color="#e0e0e0",
        cdn_resources="in_line",
    )
    net.set_options("""{
      "layout": {
        "hierarchical": {
          "enabled": true,
          "direction": "UD",
          "sortMethod": "directed",
          "levelSeparation": 120,
          "nodeSpacing": 180
        }
      },
      "edges": {
        "arrows": { "to": { "enabled": true } },
        "smooth": { "type": "cubicBezier", "forceDirection": "vertical" },
        "color": { "color": "#888888" }
      },
      "physics": { "enabled": false },
      "interaction": { "hover": true, "navigationButtons": true }
    }""")

    clusters = sorted(graph.keys())
    color_map = {c: CLUSTER_COLORS[i % len(CLUSTER_COLORS)] for i, c in enumerate(clusters)}

    added_nodes: set[str] = set()

    for cluster, nodes in graph.items():
        known = {n["name"] for n in nodes}
        color = color_map[cluster]

        for node in nodes:
            node_id = f"{cluster}/{node['name']}"
            if node_id not in added_nodes:
                tooltip = f"cluster: {cluster}"
                if node["path"]:
                    tooltip += f"\npath: {node['path']}"
                if node["interval"]:
                    tooltip += f"\ninterval: {node['interval']}"
                label = node["name"]
                if show_path and node["path"]:
                    label += f"\n{node['path']}"
                net.add_node(node_id, label=label, color=color, title=tooltip, shape="box")
                added_nodes.add(node_id)

        for node in nodes:
            node_id = f"{cluster}/{node['name']}"
            for dep in node["depends_on"]:
                dep_id = f"{cluster}/{dep}"
                if dep not in known and dep_id not in added_nodes:
                    net.add_node(dep_id, label=dep, color=DANGLING_COLOR, title=f"(unresolved in {cluster})", shape="ellipse")
                    added_nodes.add(dep_id)
                net.add_edge(node_id, dep_id)

    if out_file:
        target = str(out_file)
        net.save_graph(target)
        print(f"Saved to {target}")
    else:
        with tempfile.NamedTemporaryFile(suffix=".html", delete=False) as f:
            target = f.name
        net.save_graph(target)

    subprocess.run(["open", target])


def _mermaid_id(cluster: str, name: str) -> str:
    return f"{cluster}__{name}".replace("-", "_")


def render_mermaid(graph: dict, show_path: bool) -> str:
    lines = ["flowchart TD"]
    all_known: dict[str, set[str]] = {c: {n["name"] for n in nodes} for c, nodes in graph.items()}

    for cluster, nodes in sorted(graph.items()):
        lines.append(f"  subgraph {cluster}")
        known = all_known[cluster]
        dangling: set[str] = set()

        for node in nodes:
            nid = _mermaid_id(cluster, node["name"])
            if show_path and node["path"]:
                lines.append(f'    {nid}["{node["name"]}\\n{node["path"]}"]')
            else:
                lines.append(f'    {nid}["{node["name"]}"]')

        for node in nodes:
            nid = _mermaid_id(cluster, node["name"])
            for dep in node["depends_on"]:
                did = _mermaid_id(cluster, dep)
                if dep not in known:
                    dangling.add(dep)
                lines.append(f"    {nid} --> {did}")

        for dep in sorted(dangling):
            did = _mermaid_id(cluster, dep)
            lines.append(f"    {did}{{{{{dep}}}}}")

        lines.append("  end")

    return "\n".join(lines)


def render_text(graph: dict) -> str:
    lines = []
    for cluster, nodes in sorted(graph.items()):
        lines.append(f"[{cluster}]")
        for node in sorted(nodes, key=lambda n: n["name"]):
            if node["depends_on"]:
                deps = ", ".join(node["depends_on"])
                lines.append(f"  {node['name']} -> {deps}")
            else:
                lines.append(f"  {node['name']} (no deps)")
        lines.append("")
    return "\n".join(lines).rstrip()


def main():
    script_dir = Path(__file__).parent
    default_clusters = (script_dir / ".." / "clusters").resolve()

    parser = argparse.ArgumentParser(description="Generate a dependency graph for Flux Kustomizations")
    parser.add_argument("--clusters-dir", type=Path, default=default_clusters, metavar="PATH")
    parser.add_argument("--cluster", metavar="NAME", help="Filter to a single cluster")
    parser.add_argument("--output", choices=["html", "mermaid", "text"], default="html")
    parser.add_argument("--show-path", action="store_true", help="Include spec.path in node labels/tooltips")
    parser.add_argument("--out-file", type=Path, metavar="PATH", help="Output file path (html mode only)")
    args = parser.parse_args()

    kustomizations = collect_kustomizations(args.clusters_dir, args.cluster)
    if not kustomizations:
        print("No Flux Kustomizations found.", file=sys.stderr)
        sys.exit(1)

    graph = build_graph(kustomizations)

    if args.output == "html":
        render_html(graph, args.show_path, args.out_file)
    elif args.output == "mermaid":
        print(render_mermaid(graph, args.show_path))
    else:
        print(render_text(graph))


if __name__ == "__main__":
    main()
