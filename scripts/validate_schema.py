"""
Beckn Protocol Schema Validator
================================
Validates JSON / JSON-LD payloads against Beckn protocol schemas.

Schema discovery
----------------
The validator walks the payload recursively. At every dict node it looks for
a *type discriminator* and a *context URL*:

  - Type discriminator  → "@type" (JSON-LD) or "type" (W3C VC Data Model).
                          Both plain strings and arrays are accepted; generic
                          base types (VerifiableCredential, VerifiablePresentation)
                          are skipped when picking the domain-specific entry.
  - Context URL         → "@context" on the *same* object (inline context), or
                          the nearest "@context" from an ancestor (in-header
                          context, common in W3C VCs where @context sits at the
                          document root).

When both are found, the context URL is resolved to an attributes.yaml URL
and the object is validated against the matching component schema.

Supported URL patterns
----------------------
  GitHub raw  : .../refs/heads/<branch>/schema/<Name>/<ver>/attributes.yaml
  schema.beckn.io: schema.beckn.io/<Name>/<ver>/attributes.yaml

External $ref resolution
------------------------
The referencing.Registry is configured with an on-demand URL retriever so that
$ref values pointing to schema.beckn.io (e.g. Address/v2.0, GeoJSONGeometry/v2.0)
are fetched and resolved automatically.

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
import sys

import requests
import yaml
from jsonschema import validate, ValidationError
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012


# ---------------------------------------------------------------------------
# Type normalisation helpers
# ---------------------------------------------------------------------------

# These types appear in W3C VCs but carry no domain-specific schema information.
_GENERIC_VC_TYPES = {"VerifiableCredential", "VerifiablePresentation"}


def _normalise_type(raw_type):
    """
    Return a single domain-specific type string from a @type value.

    Used when a single representative type is needed (e.g. for context URL
    matching heuristics).  Skips generic VC base types and returns the first
    remaining entry.

    Examples:
        "beckn:Order"                                       → "beckn:Order"
        ["VerifiableCredential", "ElectricityCredential"]  → "ElectricityCredential"
        ["VerifiableCredential"]                            → "VerifiableCredential"
    """
    if isinstance(raw_type, list):
        specific = next((t for t in raw_type if t not in _GENERIC_VC_TYPES), None)
        return specific or (raw_type[0] if raw_type else "")
    return raw_type or ""


def _iter_types(raw_type):
    """
    Yield type strings from a @type value, domain-specific before generic.

    Ordering matters: by yielding domain-specific types first, the
    validated_urls deduplication set prevents the same context URL from being
    processed a second time when a generic base type (VerifiableCredential)
    resolves to the same attributes.yaml as the specific type.

    Example:
        ["VerifiableCredential", "ElectricityCredential"]
        → yields "ElectricityCredential", then "VerifiableCredential"
           The second is skipped because the URL was already processed.
    """
    if isinstance(raw_type, list):
        yield from (t for t in raw_type if t and t not in _GENERIC_VC_TYPES)
        yield from (t for t in raw_type if t and t in _GENERIC_VC_TYPES)
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
    # GitHub raw URLs
    m = re.search(r'/schema/([^/]+)/([^/]+)/attributes\.yaml', url)
    if m:
        return m.group(1), m.group(2)
    # schema.beckn.io canonical URLs
    m = re.search(r'schema\.beckn\.io/([^/]+)/([^/]+)/attributes\.yaml', url)
    if m:
        return m.group(1), m.group(2)
    return None, None


def extract_branch_from_context_url(context_url):
    """
    Extract the Git branch name embedded in a GitHub raw @context URL.

    Returns None for canonical URLs (e.g. schema.beckn.io) that carry no
    branch information.
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


def select_context_url(context_value, obj_type):
    """
    Choose the best @context URL for *obj_type* from a string or array context.

    Selection heuristic (in order):
      1. URL whose path segment matches the type name (case-insensitive).
      2. First URL that is not a well-known generic vocabulary
         (W3C credentials, schema.org, beckn Location).
      3. First string URL in the array.

    Returns a single URL string, or None if none can be found.
    """
    if isinstance(context_value, str):
        return context_value
    if not isinstance(context_value, list):
        return None

    string_urls = [u for u in context_value if isinstance(u, str)]
    if not string_urls:
        return None

    # Derive a lowercase type name for path matching (strips namespace prefix).
    type_name = _normalise_type(obj_type).split(":")[-1].lower()

    # 1. Match by type name in path
    if type_name:
        for url in string_urls:
            if f"/{type_name}/" in url.lower():
                return url

    # 2. Skip well-known generic vocabularies
    _generic = ("www.w3.org/ns/credentials", "schema.org", "/Location/")
    for url in string_urls:
        if not any(g in url for g in _generic):
            return url

    # 3. Fallback: first URL
    return string_urls[0]


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

    Bare schema.beckn.io URLs without a filename (e.g. the allOf $ref
    "https://schema.beckn.io/EnergyCredential/v2.0") are probed in order:
    first /attributes.yaml, then /schema.json, so that extensionless $refs
    in attributes.yaml files resolve correctly.
    """
    uri_str = str(uri)

    # Build the list of URLs to try, in preference order.
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


def load_core_schema_for_context_url(context_url, registry_list):
    """
    Load the core attributes.yaml for *context_url* into the registry.

    Returns the parsed schema dict, or None on failure.
    """
    registry = registry_list[0]
    attributes_url = get_attributes_url_from_context_url(context_url)

    # Return cached copy if already loaded.
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


def load_schema_for_context_url(context_url, attribute_schemas_map, registry_list=None):
    """
    Load the domain attributes.yaml for *context_url* and cache it.

    Works with both GitHub branch URLs and canonical schema.beckn.io URLs.
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


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

def _validate_attribute_object(data, schema_def, schema_type, schema_name,
                                path, errors, registry_list, schema_url=None):
    """
    Validate *data* (a domain-specific attribute object) against *schema_def*.

    Converts relative $ref values to absolute so the referencing Registry can
    resolve them, and injects @context / @type into additionalProperties=false
    schemas to allow JSON-LD annotations.
    """
    print(f"  Validating {schema_type} (from {schema_name}) at {path or 'root'}...")

    def _make_absolute_refs(obj, base_url):
        """Recursively rewrite '#/...' $ref values to '<base_url>#/...'."""
        if isinstance(obj, dict):
            return {
                k: (f"{base_url}{v}" if k == "$ref" and isinstance(v, str) and v.startswith("#")
                    else _make_absolute_refs(v, base_url))
                for k, v in obj.items()
            }
        if isinstance(obj, list):
            return [_make_absolute_refs(item, base_url) for item in obj]
        return obj

    def _allow_jsonld_annotations(schema):
        """Allow @context and @type even when additionalProperties is false."""
        if schema.get("additionalProperties") is False:
            schema.setdefault("properties", {})
            schema["properties"].setdefault("@context", {})
            schema["properties"].setdefault("@type", {})
        return schema

    # Prefer $ref-based validation (enables full nested $ref resolution).
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
# Main payload walker
# ---------------------------------------------------------------------------

def validate_payload(payload, registry_list, attributes_schema,
                     attribute_schemas_map=None, core_only=False):
    """
    Validate *payload* against Beckn / JSON-LD schemas discovered at runtime.

    Two context patterns are supported:

    Inline context
        Each object carries its own "@context" and "@type".  This is the
        standard pattern for Beckn API messages.

    In-header context
        "@context" lives at the document root (e.g. a W3C Verifiable
        Credential); child objects carry only "@type" (or "type").  The root
        context is propagated down through recursive calls so inner objects
        can still be matched to a schema.

    "@type" may be a plain string or an array; generic base types such as
    "VerifiableCredential" are skipped when choosing the domain type.

    The W3C VC plain "type" field is accepted as a fallback for "@type".
    """
    errors = []

    # Phase 1: validate core beckn message envelope when present.
    if isinstance(payload, dict) and "message" in payload:
        _validate_core_structure(payload, registry_list, errors)

    def _walk(data, path="", inherited_context=None):
        """
        Walk *data* recursively.

        *inherited_context* carries the nearest ancestor "@context" value so
        that child objects without their own "@context" (in-header pattern)
        can still be matched to a schema.
        """
        if not isinstance(data, dict):
            if isinstance(data, list):
                for idx, item in enumerate(data):
                    _walk(item, f"{path}[{idx}]", inherited_context)
            return

        own_context = data.get("@context")

        # "type" (no @) is the W3C VC Data Model form; "@type" is JSON-LD.
        raw_type = data.get("@type") or data.get("type")

        # Active context: own context takes priority over inherited header context.
        active_context = own_context if own_context is not None else inherited_context

        if active_context and raw_type and attribute_schemas_map is not None:
            # Iterate over every type in the array so objects with multiple-type
            # inheritance (e.g. ["VerifiableCredential", "ElectricityCredential"])
            # are validated against each schema that can be resolved.
            # validated_urls guards against processing the same schema twice when
            # two types in the array resolve to the same context URL.
            validated_urls: set = set()

            for obj_type in _iter_types(raw_type):
                context_url = select_context_url(active_context, obj_type)
                if context_url is None or context_url in validated_urls:
                    continue
                validated_urls.add(context_url)

                if obj_type.startswith("beckn:") and is_core_context_url(context_url):
                    # --- Core beckn object (beckn:Order, beckn:Offer, …) ---
                    attrs_url = get_attributes_url_from_context_url(context_url)
                    if attrs_url not in registry_list[0]:
                        load_core_schema_for_context_url(context_url, registry_list)
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

                elif not obj_type.startswith("beckn:") and not core_only:
                    # --- Domain-specific attribute object ---
                    if context_url not in attribute_schemas_map:
                        load_schema_for_context_url(context_url, attribute_schemas_map, registry_list)

                    if context_url in attribute_schemas_map:
                        schema_name, schema_data, schema_url = attribute_schemas_map[context_url]
                        schema_type = obj_type.split(":")[-1] if ":" in obj_type else obj_type
                        schemas = (schema_data.get("components") or {}).get("schemas") or {}

                        # Exact match first; case-insensitive fallback.
                        matched = schema_type if schema_type in schemas else next(
                            (k for k in schemas if k.lower() == schema_type.lower()), None
                        )

                        # When using inherited (in-header) context, only validate
                        # if the type is an explicit component in the schema.
                        # This prevents false positives from generic "type" fields
                        # (GeoJSON "Point", proof types, etc.) that happen to sit
                        # under an ancestor with @context.
                        if matched is None and own_context is None:
                            continue

                        schema_def = schemas.get(matched) if matched else schema_data
                        _validate_attribute_object(
                            data, schema_def, matched or schema_type,
                            schema_name, path, errors, registry_list, schema_url,
                        )

        # Recurse into children, propagating the active context so descendants
        # without their own @context (in-header pattern) can still be validated.
        next_inherited = own_context if own_context is not None else inherited_context
        for key, value in data.items():
            if key != "@context":   # don't recurse into the context definition itself
                _walk(value, f"{path}/{key}" if path else key, next_inherited)

    _walk(payload)
    return errors


# ---------------------------------------------------------------------------
# File and Postman collection processing
# ---------------------------------------------------------------------------

def process_file(filepath, registry_list, attributes_schema,
                 attribute_schemas_map=None, core_only=False):
    """
    Load *filepath* (JSON file or Postman collection) and validate its payload.
    """
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
