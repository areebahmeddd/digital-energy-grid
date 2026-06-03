"""
Beckn Protocol Schema Validator
================================
Validates JSON / JSON-LD payloads against Beckn protocol schemas.

Schema discovery
----------------
The validator walks the payload recursively. At every dict node it looks for
a *type discriminator* and a *context*:

  - Type discriminator  → "@type" (JSON-LD) or "type" (W3C VC Data Model).
                          Both plain strings and arrays are accepted.
  - Context             → "@context" on the *same* object (inline context), or
                          the nearest "@context" inherited from an ancestor
                          (in-header context — common in W3C VCs where @context
                          sits at the document root).

For every URL in the active @context array the validator loads the sibling
attributes.yaml and collects all declared schema components into a flat lookup
table.  Each type in @type is looked up in that table by name (case-insensitive).
This means type names do NOT need to match context file names — the validator
finds the right schema by content, not by URL path heuristics.

Supported URL patterns
----------------------
  GitHub raw    : .../refs/heads/<branch>/schema/<Name>/<ver>/attributes.yaml
  schema.beckn.io : schema.beckn.io/<Name>/<ver>/attributes.yaml

External $ref resolution
------------------------
The referencing.Registry is configured with an on-demand URL retriever so that
$ref values pointing to schema.beckn.io (e.g. Address/v2.0, GeoJSONGeometry/v2.0)
are fetched and resolved automatically without pre-registration.

Usage
-----
  # Validate one file:
  python3 scripts/validate_schema.py examples/ev-charging/v2/03_select/select.json

  # Validate a glob:
  python3 scripts/validate_schema.py examples/ev-charging/v2/**/*.json

  # Skip domain-specific attributes, only core beckn objects:
  python3 scripts/validate_schema.py --core-only examples/...

  # Validate a Postman collection:
  python3 scripts/validate_schema.py devkits/ev-charging/postman/BAP.postman_collection.json
"""

import copy
import json
import re

import requests
import yaml
from jsonschema import validate, ValidationError
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012


# ---------------------------------------------------------------------------
# Type helpers
# ---------------------------------------------------------------------------

# Well-known W3C VC base types that carry no domain-specific schema.
_GENERIC_VC_TYPES = {"VerifiableCredential", "VerifiablePresentation"}


def _iter_types(raw_type):
    """
    Yield every type string from a @type value (string or array).

    With component-map lookup (see _components_for_context) the order of
    iteration no longer affects which schema is chosen — each type is looked
    up independently by name.
    """
    if isinstance(raw_type, list):
        yield from (t for t in raw_type if t)
    elif raw_type:
        yield raw_type


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def load_schema_from_url(url):
    """Fetch and parse a YAML or JSON schema from *url*."""
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    return yaml.safe_load(response.text)


def extract_schema_info_from_url(url):
    """
    Return (schema_name, version) from an attributes.yaml URL.

    Supports:
      GitHub : .../schema/<Name>/<ver>/attributes.yaml
      beckn  : schema.beckn.io/<Name>/<ver>/attributes.yaml
    Returns (None, None) when neither pattern matches.
    """
    m = re.search(r'/schema/([^/]+)/([^/]+)/attributes\.yaml', url)
    if m:
        return m.group(1), m.group(2)
    m = re.search(r'schema\.beckn\.io/([^/]+)/([^/]+)/attributes\.yaml', url)
    if m:
        return m.group(1), m.group(2)
    return None, None


def extract_branch_from_context_url(context_url):
    """
    Extract the Git branch embedded in a GitHub raw @context URL.
    Returns None for canonical URLs (e.g. schema.beckn.io) with no branch.
    """
    m = re.search(r'/refs/heads/([^/]+)/(?:specification/)?schema/', context_url)
    if m:
        return m.group(1)
    m = re.search(r'/tags/([^/]+)/(?:specification/)?schema/', context_url)
    if m:
        return m.group(1)
    return None


def get_attributes_url_from_context_url(context_url):
    """Convert a context.jsonld URL to the sibling attributes.yaml URL."""
    return context_url.replace('/context.jsonld', '/attributes.yaml')


def is_core_context_url(context_url):
    """Return True when the URL points to the Beckn core schema."""
    return '/schema/core/' in context_url


# ---------------------------------------------------------------------------
# On-demand URL retriever for the referencing Registry
# ---------------------------------------------------------------------------

def _retrieve_url(uri):
    """
    Fetch and parse a schema from *uri* on demand.

    The referencing.Registry calls this whenever it encounters an unregistered
    $ref URI (e.g. https://schema.beckn.io/Address/v2.0/attributes.yaml#/…).

    Bare schema.beckn.io URLs without a filename extension (e.g. the allOf
    $ref "https://schema.beckn.io/EnergyCredential/v2.0") are probed first
    with /attributes.yaml, then /schema.json.
    """
    uri_str = str(uri)

    if "schema.beckn.io" in uri_str and not uri_str.endswith((".yaml", ".json")):
        candidates = [f"{uri_str}/attributes.yaml", f"{uri_str}/schema.json"]
    else:
        candidates = [uri_str]

    last_exc: Exception = RuntimeError(f"No candidates for {uri_str}")
    for url in candidates:
        try:
            resp = requests.get(url, timeout=15)
            resp.raise_for_status()
            content = (yaml.safe_load(resp.text) if url.endswith(".yaml")
                       else json.loads(resp.text))
            return Resource.from_contents(content, DRAFT202012)
        except Exception as exc:
            last_exc = exc

    raise Exception(f"Cannot retrieve {uri_str}: {last_exc}") from last_exc


def get_schema_store():
    """
    Create a fresh schema store.

    Returns (registry_list, None, attribute_schemas_map) where:
      registry_list        – single-element list wrapping the (immutable)
                             Registry so callees can replace it via index 0.
      attribute_schemas_map – dict mapping @context URL → (name, data, url).
    """
    registry = Registry(retrieve=_retrieve_url)
    return [registry], None, {}


# ---------------------------------------------------------------------------
# Schema loading
# ---------------------------------------------------------------------------

CORE_BECKN_SCHEMA_URL = (
    "https://raw.githubusercontent.com/beckn/protocol-specifications-v2"
    "/refs/tags/core-v2.0.0-lts/api/v2.0.0/beckn.yaml"
)


def load_schema_for_context_url(context_url, attribute_schemas_map, registry_list=None):
    """
    Load the attributes.yaml for *context_url* and cache it.

    Converts context.jsonld → attributes.yaml, fetches the schema, and
    registers it in the referencing Registry.  Works with both GitHub branch
    URLs and canonical schema.beckn.io URLs.

    Returns (schema_name, schema_data, attributes_url), or None on failure.
    """
    if context_url in attribute_schemas_map:
        return attribute_schemas_map[context_url]

    attributes_url = get_attributes_url_from_context_url(context_url)
    schema_name, version = extract_schema_info_from_url(attributes_url)
    if not schema_name:
        return None

    branch = extract_branch_from_context_url(context_url)

    try:
        schema_data = load_schema_from_url(attributes_url)
        attribute_schemas_map[context_url] = (schema_name, schema_data, attributes_url)
        if registry_list is not None:
            registry_list[0] = registry_list[0].with_resource(
                attributes_url, Resource.from_contents(schema_data, DRAFT202012)
            )
        source = f"branch: {branch}" if branch else attributes_url
        print(f"  Loaded: {schema_name}/{version} ({source})")
        return (schema_name, schema_data, attributes_url)
    except Exception as e:
        print(f"  Warning: Failed to load {schema_name}/{version} from {attributes_url}: {e}")
        return None


def load_core_schema_for_context_url(context_url, registry_list):
    """
    Load the core attributes.yaml for *context_url* into the registry.
    Returns the parsed schema dict, or None on failure.
    """
    registry = registry_list[0]
    attributes_url = get_attributes_url_from_context_url(context_url)

    try:
        resource = registry.get(attributes_url)
        if resource is not None:
            return resource.contents
    except (KeyError, AttributeError):
        pass

    try:
        schema_data = load_schema_from_url(attributes_url)
        registry_list[0] = registry.with_resource(
            attributes_url, Resource.from_contents(schema_data, DRAFT202012)
        )
        branch = extract_branch_from_context_url(context_url)
        print(f"  Loaded core attributes schema (branch: {branch})")
        return schema_data
    except Exception as e:
        print(f"  Warning: Failed to load core attributes schema from {attributes_url}: {e}")
        return None


def _load_core_beckn_schema(registry_list):
    """Load and cache the core beckn.yaml schema. Returns None on failure."""
    url = CORE_BECKN_SCHEMA_URL
    try:
        resource = registry_list[0].get(url)
        if resource is not None:
            return resource.contents
    except (KeyError, AttributeError):
        pass
    try:
        schema_data = load_schema_from_url(url)
        registry_list[0] = registry_list[0].with_resource(
            url, Resource.from_contents(schema_data, DRAFT202012)
        )
        print("  Loaded core beckn.yaml schema")
        return schema_data
    except Exception as e:
        print(f"  Warning: Failed to load core beckn.yaml: {e}")
        return None


# ---------------------------------------------------------------------------
# Component map — the heart of schema discovery
# ---------------------------------------------------------------------------

def _components_for_context(context_value, attribute_schemas_map, registry_list):
    """
    Build a flat map of every schema component reachable from *context_value*.

    For each URL in the @context array (string or list) that ends with
    '/context.jsonld', the sibling attributes.yaml is loaded (results are
    cached in attribute_schemas_map) and its components/schemas entries are
    merged into the returned dict.

    Return value:
        { component_name_lower: (schema_def, schema_name, schema_url, canonical_key) }

    URLs with no sibling attributes.yaml (W3C credentials context, schema.org,
    etc.) are silently skipped.

    Because types are looked up by component name rather than by URL path,
    type names do not need to match context file names, and the order of
    types in @type arrays does not affect which schema is chosen.
    """
    if isinstance(context_value, str):
        context_urls = [context_value]
    elif isinstance(context_value, list):
        context_urls = [u for u in context_value if isinstance(u, str)]
    else:
        return {}

    combined = {}
    for ctx_url in context_urls:
        # Only process URLs that are context.jsonld files — others (W3C, schema.org)
        # have no sibling attributes.yaml and are intentionally skipped.
        if not ctx_url.endswith('/context.jsonld'):
            continue

        if ctx_url not in attribute_schemas_map:
            load_schema_for_context_url(ctx_url, attribute_schemas_map, registry_list)

        if ctx_url not in attribute_schemas_map:
            continue  # loading failed — skip silently

        _, schema_data, schema_url = attribute_schemas_map[ctx_url]
        schema_name, _ = extract_schema_info_from_url(schema_url)
        for key, defn in (schema_data.get("components") or {}).get("schemas", {}).items():
            # Later entries win if two context files define the same component name,
            # which mirrors JSON-LD's last-definition-wins semantics.
            combined[key.lower()] = (defn, schema_name or key, schema_url, key)

    return combined


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

def _validate_attribute_object(data, schema_def, schema_type, schema_name,
                                path, errors, registry_list, schema_url=None):
    """
    Validate *data* against *schema_def* (a domain-specific component schema).

    Converts relative '#/...' $ref values to absolute so the referencing
    Registry can resolve them, and injects @context / @type into schemas that
    have additionalProperties=false to allow JSON-LD annotations.
    """
    print(f"  Validating {schema_type} (from {schema_name}) at {path or 'root'}...")

    def _make_absolute_refs(obj, base_url):
        """Rewrite '#/...' $ref values to '<base_url>#/...'."""
        if isinstance(obj, dict):
            return {
                k: (f"{base_url}{v}" if k == "$ref" and isinstance(v, str) and v.startswith("#")
                    else _make_absolute_refs(v, base_url))
                for k, v in obj.items()
            }
        if isinstance(obj, list):
            return [_make_absolute_refs(i, base_url) for i in obj]
        return obj

    def _allow_jsonld_annotations(schema):
        """Allow @context and @type even when additionalProperties is false."""
        if schema.get("additionalProperties") is False:
            schema.setdefault("properties", {})
            schema["properties"].setdefault("@context", {})
            schema["properties"].setdefault("@type", {})
        return schema

    # Preferred path: $ref-based validation enables full nested $ref resolution.
    if schema_url:
        try:
            full_doc = registry_list[0].get(schema_url)
            if full_doc:
                schemas = (full_doc.contents.get("components") or {}).get("schemas") or {}
                if schema_type in schemas:
                    resolved = _allow_jsonld_annotations(
                        _make_absolute_refs(copy.deepcopy(schemas[schema_type]), schema_url)
                    )
                    validate(instance=data, schema=resolved, registry=registry_list[0])
                    print(f"  {schema_type} at {path or 'root'} is VALID.")
                    return
        except ValidationError as e:
            print(f"  {schema_type} at {path or 'root'} is INVALID: {e.message}")
            print(f"  Path: {e.json_path}")
            errors.append(f"{path} ({schema_type}): {e.message}")
            return
        except Exception:
            pass  # Fall through to direct validation

    # Fallback: validate directly from the schema fragment.
    try:
        fallback = _allow_jsonld_annotations(copy.deepcopy(schema_def))
        validate(instance=data, schema=fallback, registry=registry_list[0])
        print(f"  {schema_type} at {path or 'root'} is VALID.")
    except ValidationError as e:
        print(f"  {schema_type} at {path or 'root'} is INVALID: {e.message}")
        print(f"  Path: {e.json_path}")
        errors.append(f"{path} ({schema_type}): {e.message}")


def _validate_core_structure(payload, registry_list, errors):
    """
    Validate message.contract / message.order against core beckn.yaml.
    Catches missing required fields on Contract, Order, Commitment, etc.
    """
    message = payload.get("message")
    if not isinstance(message, dict):
        return

    core_schema = _load_core_beckn_schema(registry_list)
    if not core_schema:
        return

    schemas = (core_schema.get("components") or {}).get("schemas") or {}
    for key, schema_name in [("contract", "Contract"), ("order", "Order")]:
        obj = message.get(key)
        if not isinstance(obj, dict) or schema_name not in schemas:
            continue
        print(f"  Validating message.{key} against core {schema_name} schema...")
        try:
            validate(
                instance=obj,
                schema={"$ref": f"{CORE_BECKN_SCHEMA_URL}#/components/schemas/{schema_name}"},
                registry=registry_list[0],
            )
            print(f"  message.{key} core structure is VALID.")
        except ValidationError as e:
            print(f"  message.{key} core structure is INVALID: {e.message}")
            print(f"  Path: {e.json_path}")
            errors.append(f"message/{key}{e.json_path.lstrip('$')}: {e.message}")


# ---------------------------------------------------------------------------
# Main payload walker
# ---------------------------------------------------------------------------

def validate_payload(payload, registry_list, attributes_schema,
                     attribute_schemas_map=None, core_only=False):
    """
    Validate *payload* against Beckn / JSON-LD schemas discovered at runtime.

    Schema discovery
    ~~~~~~~~~~~~~~~~
    For every dict node in the payload that carries a type discriminator
    ("@type" or "type") and an active context ("@context" on the node itself
    or inherited from an ancestor), the validator:

      1. Loads every attributes.yaml reachable from the @context array.
      2. Builds a flat component map: {name_lower → schema_def}.
      3. Looks up each type in @type by name (case-insensitive).
      4. Validates the object against each found component schema.

    Because lookup is by component name rather than URL path, type names do
    not need to match context file names, and the order of types in @type
    arrays does not matter.

    In-header context
    ~~~~~~~~~~~~~~~~~
    "@context" at the document root is propagated to all descendants so that
    W3C VCs (where @context lives only at the root) are handled correctly.
    When using inherited context, a node is only validated if its type matches
    an explicit component — this prevents false positives from generic "type"
    fields (GeoJSON "Point", proof types, etc.).
    """
    errors = []

    # Phase 1: validate core beckn message envelope when present.
    if isinstance(payload, dict) and "message" in payload:
        _validate_core_structure(payload, registry_list, errors)

    def _walk(data, path="", inherited_context=None):
        """
        Recursively walk *data*, validating every JSON-LD-typed object.

        *inherited_context* is the nearest ancestor's @context value, used
        when the current node has no own @context (in-header context pattern).
        """
        if not isinstance(data, dict):
            if isinstance(data, list):
                for idx, item in enumerate(data):
                    _walk(item, f"{path}[{idx}]", inherited_context)
            return

        own_context = data.get("@context")
        # W3C VCs use "type" (no @); JSON-LD uses "@type".  Support both.
        raw_type = data.get("@type") or data.get("type")

        # Active context: own context takes priority over inherited ancestor context.
        active_context = own_context if own_context is not None else inherited_context

        if active_context and raw_type and attribute_schemas_map is not None:

            # Build (or reuse cached) flat map of all components across every
            # attributes.yaml reachable from the active context.
            context_components = _components_for_context(
                active_context, attribute_schemas_map, registry_list
            )

            for obj_type in _iter_types(raw_type):

                if obj_type.startswith("beckn:"):
                    # ----- Core beckn object (beckn:Order, beckn:Offer, …) -----
                    # Core objects still use URL-based context selection because
                    # they need the specific core/v2/attributes.yaml URL for $ref.
                    # Find the first core context URL from the active context.
                    core_ctx = next(
                        (u for u in ([active_context] if isinstance(active_context, str)
                                     else active_context)
                         if isinstance(u, str) and is_core_context_url(u)),
                        None,
                    )
                    if core_ctx is None:
                        continue
                    attrs_url = get_attributes_url_from_context_url(core_ctx)
                    if attrs_url not in registry_list[0]:
                        load_core_schema_for_context_url(core_ctx, registry_list)
                    try:
                        resource = registry_list[0].get(attrs_url)
                        if resource:
                            object_name = obj_type.split(":")[-1]
                            schemas = (resource.contents.get("components") or {}).get("schemas") or {}
                            if object_name in schemas:
                                print(f"  Validating {object_name} at {path or 'root'}...")
                                try:
                                    validate(
                                        instance=data,
                                        schema={"$ref": f"{attrs_url}#/components/schemas/{object_name}"},
                                        registry=registry_list[0],
                                    )
                                    print(f"  {object_name} at {path or 'root'} is VALID.")
                                except ValidationError as e:
                                    print(f"  {object_name} at {path or 'root'} is INVALID: {e.message}")
                                    errors.append(f"{path}: {e.message}")
                                except Exception as e:
                                    print(f"  Warning: $ref resolution failed for {object_name}: {e}")
                    except (KeyError, AttributeError):
                        pass

                elif not core_only:
                    # ----- Domain-specific attribute object -----
                    # Look up by component name across all schemas loaded from
                    # the active context — no URL path matching needed.
                    schema_type = obj_type.split(":")[-1] if ":" in obj_type else obj_type
                    match = (context_components.get(schema_type) or
                             context_components.get(schema_type.lower()))

                    if match is None:
                        # When using inherited context, skip unknown types
                        # silently — they are not domain objects from this schema.
                        # (With own @context we also skip: an unknown type in
                        # its own context likely has no schema defined for it.)
                        continue

                    schema_def, schema_name, schema_url, component_key = match
                    _validate_attribute_object(
                        data, schema_def, component_key, schema_name,
                        path, errors, registry_list, schema_url,
                    )

        # Recurse into children, propagating the active context for
        # descendants that have no own @context (in-header context pattern).
        next_inherited = own_context if own_context is not None else inherited_context
        for key, value in data.items():
            if key != "@context":
                _walk(value, f"{path}/{key}" if path else key, next_inherited)

    _walk(payload)
    return errors


# ---------------------------------------------------------------------------
# File and Postman collection processing
# ---------------------------------------------------------------------------

def process_file(filepath, registry_list, attributes_schema,
                 attribute_schemas_map=None, core_only=False):
    """Load *filepath* (JSON file or Postman collection) and validate it."""
    print(f"Processing {filepath}...")
    try:
        with open(filepath, "r") as f:
            data = json.load(f)

        if "info" in data and "_postman_id" in data.get("info", {}):
            print("  Identified as Postman collection.")
            _traverse_postman_items(data.get("item", []), registry_list,
                                    attributes_schema, attribute_schemas_map, core_only)
        else:
            validate_payload(data, registry_list, attributes_schema,
                             attribute_schemas_map, core_only)
    except Exception as e:
        print(f"  Error processing {filepath}: {e}")


def _traverse_postman_items(items, registry_list, attributes_schema,
                             attribute_schemas_map, core_only=False):
    """Recursively extract and validate JSON bodies from a Postman collection."""
    for item in items:
        if "item" in item:
            _traverse_postman_items(item["item"], registry_list,
                                    attributes_schema, attribute_schemas_map, core_only)
        request = item.get("request", {})
        body = request.get("body", {})
        if body.get("mode") == "raw":
            try:
                json_body = json.loads(body["raw"])
                validate_payload(json_body, registry_list, attributes_schema,
                                 attribute_schemas_map, core_only)
            except json.JSONDecodeError:
                pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate JSON files against Beckn protocol schemas.",
        epilog="Example: python3 scripts/validate_schema.py examples/ev-charging/v2/**/*.json",
    )
    parser.add_argument("files", nargs="+",
                        help="JSON files or Postman collections to validate.")
    parser.add_argument("--core-only", action="store_true", default=False,
                        help="Only validate core Beckn objects; skip domain-specific attributes.")

    args = parser.parse_args()
    registry, attributes_schema, attribute_schemas_map = get_schema_store()

    for file in args.files:
        process_file(file, registry, attributes_schema, attribute_schemas_map,
                     core_only=args.core_only)
