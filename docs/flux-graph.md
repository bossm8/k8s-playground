# Flux Kustomization Dependency Graph

Visualises the `spec.dependsOn` relationships between Flux Kustomization resources
by parsing the YAML files in `clusters/` statically — no cluster connection needed.

## Prerequisites

- Python 3

```bash
python3 -m venv .venv
.venv/bin/pip install -r helpers/requirements.txt
```

## Usage

```bash
.venv/bin/python3 helpers/flux-dep-graph.py [OPTIONS]
```

| Flag | Default | Description |
| --- | --- | --- |
| `--clusters-dir PATH` | `clusters/` | Path to the clusters directory |
| `--cluster NAME` | _(all clusters)_ | Filter output to a single cluster |
| `--output html\|mermaid\|text` | `html` | Output format |
| `--show-path` | off | Include `spec.path` in node labels / tooltips |
| `--out-file PATH` | _(temp file)_ | Save HTML output to a named file instead of a temp file |

## Output formats

### html (default)

Opens an interactive [vis.js](https://visjs.org/) graph in the browser.
Nodes are colored by cluster, arrows point from a dependent toward its dependency
(roots float to the top), and hovering a node shows its `path` and `interval`.

```bash
# Open in browser
.venv/bin/python3 helpers/flux-dep-graph.py

# Save to a named file
.venv/bin/python3 helpers/flux-dep-graph.py --out-file graph.html
```

### mermaid

Prints a `flowchart TD` block to stdout. Paste it into a GitHub issue, a
README, or [mermaid.live](https://mermaid.live) to render it.

```bash
.venv/bin/python3 helpers/flux-dep-graph.py --output mermaid
```

### text

Plain-text dependency summary, one line per Kustomization, grouped by cluster.
Useful for quick terminal inspection.

```bash
.venv/bin/python3 helpers/flux-dep-graph.py --output text
```

## Notes

- Only `kustomize.toolkit.fluxcd.io/v1` Kustomizations are included.
- If a `dependsOn` target is not defined within the same cluster, a warning is
  printed to stderr and the missing node appears as a red ellipse in the HTML graph.
