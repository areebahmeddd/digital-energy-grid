#!/usr/bin/env python3
"""Bundle a credential's attributes.yaml into a self-contained schema.json.

The canonical source of truth is the per-schema ``attributes.yaml`` files (this
repo) plus the reserved Beckn core schemas published at schema.nfh.global
(Location, GeoJSONGeometry, Address, …). Those leaf schemas reference each other
by ``https://schema.nfh.global/<Schema>/<ver>#/components/schemas/<Name>`` URLs.

This tool resolves that whole reference graph into one flat ``$defs`` map and
rewrites every ``$ref`` to ``#/$defs/<Name>`` so the result validates with no
network access. Resolution is **local-first**: a ref is read from
``specification/schema/<Schema>/<ver>/attributes.yaml`` when that file exists
(so unpublished local edits win), otherwise it is fetched live from
schema.nfh.global and cached for the run.

The curated W3C-VC **root envelope** (``@context``, ``id`` pattern, ``issuer``,
``validFrom``/``validUntil``, ``proof`` …) is NOT mechanically derivable from the
OpenAPI sources — it encodes VC Data Model 2.0 authoring choices. So the root
(everything except ``$defs``) is preserved from the existing schema.json; only
the ``$defs`` graph is regenerated. Run with --check to fail on drift (CI).

Each bundled component keeps ``description``, ``x-standard`` and all validation
keywords; authoring/JSON-LD cruft (``x-jsonld``, ``x-tags``, ``$id``, ``x-iri``,
``example``, ``servers``) is stripped.

Usage:
  python3 specification/scripts/bundle_schema.py specification/schema/ElectricityCredential/v1.2
  python3 specification/scripts/bundle_schema.py --all
  python3 specification/scripts/bundle_schema.py specification/schema/ElectricityCredential/v1.2 --check
"""
from __future__ import annotations

import argparse
import copy
import glob
import json
import os
import sys
import urllib.request

import yaml

BECKN = "https://schema.nfh.global/"
STRIP_KEYS = {"x-jsonld", "x-tags", "$id", "x-iri", "x-id", "example", "servers", "$schema"}
SCHEMA_ROOT = os.path.dirname(os.path.abspath(__file__)).replace(
    os.path.join("specification", "scripts"), os.path.join("specification", "schema")
)

_file_cache: dict[str, dict] = {}


def load_yaml_file(path: str) -> dict:
    if path not in _file_cache:
        with open(path, encoding="utf-8") as f:
            _file_cache[path] = yaml.safe_load(f)
    return _file_cache[path]


def fetch_remote(url: str) -> dict:
    if url not in _file_cache:
        with urllib.request.urlopen(url, timeout=20) as r:  # noqa: S310 (trusted registry)
            _file_cache[url] = yaml.safe_load(r.read().decode("utf-8"))
    return _file_cache[url]


def schema_doc_for(schema: str, ver: str) -> dict:
    """Return the OpenAPI doc for <schema>/<ver>, local file first, else fetched."""
    local = os.path.join(SCHEMA_ROOT, schema, ver, "attributes.yaml")
    if os.path.exists(local):
        return load_yaml_file(local)
    return fetch_remote(f"{BECKN}{schema}/{ver}/attributes.yaml")


def parse_ref(ref: str, ctx: tuple[str, str] | None):
    """Resolve a $ref to (component_name, (schema, ver)).

    ctx is the (schema, ver) the ref appears in, used for internal/anchor refs.
    Handles:
      #/components/schemas/X, #X (anchor)                 -> internal to ctx
      https://schema.nfh.global/<S>/<v>[/attributes.yaml]#/components/schemas/X
      https://schema.nfh.global/<S>/<v>#X                   -> anchor in <S>/<v>
      https://schema.nfh.global/<S>/<v>                     -> whole-schema (name = S)
    """
    if ref.startswith("#"):
        frag = ref[1:]
        name = frag.split("/")[-1]
        return name, ctx
    assert ref.startswith(BECKN), f"unexpected ref: {ref}"
    path, _, frag = ref[len(BECKN):].partition("#")
    parts = [p for p in path.split("/") if p and p != "attributes.yaml"]
    schema, ver = parts[0], parts[1]
    if frag:
        name = frag.lstrip("/").split("/")[-1]
    else:
        name = schema  # whole-schema ref -> the same-named component
    return name, (schema, ver)


def get_component(name: str, ctx: tuple[str, str]) -> tuple[dict, tuple[str, str]]:
    """Fetch components.schemas[name] from ctx's doc. If it is a thin alias
    ({$ref, description} with no validation), follow the alias, carrying the
    local description down. Returns (node, ctx_of_returned_node)."""
    doc = schema_doc_for(*ctx)
    node = doc["components"]["schemas"][name]
    extra = {k: v for k, v in node.items() if k not in ("$ref", "description")}
    if "$ref" in node and not extra:
        tname, tctx = parse_ref(node["$ref"], ctx)
        target, tctx = get_component(tname, tctx)
        target = copy.deepcopy(target)
        if node.get("description"):
            target["description"] = node["description"]  # local alias desc wins
        return target, tctx
    return node, ctx


class Bundler:
    def __init__(self):
        self.defs: dict[str, dict] = {}
        self.ctx_of: dict[str, tuple[str, str]] = {}

    def rewrite(self, node, ctx):
        """Deep-clean a node: strip cruft, rewrite $refs to #/$defs/, enqueue targets."""
        if isinstance(node, dict):
            if "$ref" in node:
                name, tctx = parse_ref(node["$ref"], ctx)
                self.want(name, tctx)
                out = {"$ref": f"#/$defs/{name}"}
                for k, v in node.items():
                    if k != "$ref" and k not in STRIP_KEYS:
                        out[k] = self.rewrite(v, ctx)
                return out
            return {k: self.rewrite(v, ctx) for k, v in node.items() if k not in STRIP_KEYS}
        if isinstance(node, list):
            return [self.rewrite(v, ctx) for v in node]
        return node

    def want(self, name: str, ctx: tuple[str, str]):
        if name in self.defs:
            return
        self.defs[name] = {}  # reserve (breaks ref cycles)
        node, real_ctx = get_component(name, ctx)
        self.defs[name] = self.rewrite(node, real_ctx)

    def build(self, root_doc_refs, ctx):
        for name in root_doc_refs:
            self.want(name, ctx)


def defs_referenced_in(obj, acc):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "$ref" and isinstance(v, str) and v.startswith("#/$defs/"):
                acc.add(v.split("/")[-1])
            else:
                defs_referenced_in(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            defs_referenced_in(v, acc)


def bundle(version_dir: str) -> dict:
    norm = os.path.normpath(version_dir)
    ver = os.path.basename(norm)
    schema = os.path.basename(os.path.dirname(norm))
    existing_path = os.path.join(version_dir, "schema.json")
    with open(existing_path, encoding="utf-8") as f:
        existing = json.load(f)

    # Preserve the curated root; regenerate $defs from the leaf graph.
    root = {k: v for k, v in existing.items() if k != "$defs"}
    seeds: set[str] = set()
    defs_referenced_in(root, seeds)

    b = Bundler()
    b.build(sorted(seeds), (schema, ver))

    out = dict(root)
    out["$defs"] = {k: b.defs[k] for k in b.defs}
    return out


def process(version_dir: str, check: bool) -> bool:
    out = bundle(version_dir)
    path = os.path.join(version_dir, "schema.json")
    new = json.dumps(out, indent=4, ensure_ascii=False) + "\n"
    with open(path, encoding="utf-8") as f:
        cur = f.read()
    if new == cur:
        print(f"unchanged: {path}")
        return True
    if check:
        print(f"STALE: {path} (run without --check to regenerate)")
        return False
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)
    print(f"bundled:   {path}  ({len(out['$defs'])} \\$defs)")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("dirs", nargs="*", help="schema version dir(s)")
    ap.add_argument("--all", action="store_true", help="every schema version dir with a schema.json")
    ap.add_argument("--check", action="store_true", help="fail if any bundle is stale (no writes)")
    args = ap.parse_args()
    if args.all:
        args.dirs = sorted(os.path.dirname(p) for p in glob.glob(os.path.join(SCHEMA_ROOT, "*", "*", "schema.json")))
    if not args.dirs:
        ap.error("pass one or more version dirs, or --all")
    ok = all(process(d, args.check) for d in args.dirs)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
