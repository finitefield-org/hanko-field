#!/usr/bin/env python3
"""Builds markdown reference docs from doc/api/api.yaml."""
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List

import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
SPEC_PATH = REPO_ROOT / 'doc' / 'api' / 'api.yaml'
OUTPUT_PATH = Path(__file__).resolve().parent / 'README.md'
BASE_URL = 'https://hanko-api.a.run.app/api/v1'
MAX_OBJECT_PROPS = 5
MAX_DEPTH = 3

DOMAIN_DESCRIPTIONS = {
    'Public': 'Cache-friendly catalog, template, promotion, and health endpoints that do not require authentication.',
    'Auth': 'Authenticated customer profile, addresses, favorites, payment methods, and transliteration helpers.',
    'Designs': 'User-owned design lifecycle plus AI suggestion orchestration.',
    'Cart': 'Cart header, line items, promotions, and checkout orchestration endpoints for signed-in buyers.',
    'Orders': 'Customer-facing order, payment, shipment, and reorder operations scoped to the caller.',
    'Reviews': 'End-user review submission and retrieval endpoints.',
    'Assets': 'Signed upload/download helpers for design previews and supporting documents.',
    'Admin': 'Staff/admin-only catalog, promotion, content, order, production, counter, and audit operations.',
    'Webhooks': 'Inbound integrations from PSPs, shipping carriers, and AI workers with HMAC verification.',
    'Internal': 'Service-to-service endpoints invoked by background jobs, Cloud Run jobs, or Cloud Scheduler.',
}

DOMAIN_AUTH = {
    'Public': 'None (anonymous HTTPS).',
    'Auth': 'Firebase Auth ID token (role=user, own resources).',
    'Designs': 'Firebase Auth ID token (role=user owns the design) or staff override with `designs.*` scope.',
    'Cart': 'Firebase Auth ID token (role=user).',
    'Orders': 'Firebase Auth ID token (role=user) scoped to order owner.',
    'Reviews': 'Firebase Auth ID token (role=user).',
    'Assets': 'Firebase Auth ID token (role=user or staff).',
    'Admin': 'Firebase Auth ID token with custom claim `role=staff` or `role=admin` plus required scopes.',
    'Webhooks': 'HMAC signature header (per integration secret).',
    'Internal': 'Workload Identity / OIDC server-to-server token (system role).',
}

IDEMPOTENT_METHODS = {'POST', 'PUT', 'PATCH', 'DELETE'}


def main() -> None:
    spec = yaml.safe_load(SPEC_PATH.read_text())
    grouped = group_operations(spec)
    doc = render_markdown(spec, grouped)
    OUTPUT_PATH.write_text(doc)
    print(f'Wrote {OUTPUT_PATH.relative_to(REPO_ROOT)} ({len(doc.splitlines())} lines)')


def group_operations(spec: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for path, path_item in spec.get('paths', {}).items():
        path_params = path_item.get('parameters', [])
        for method, op in path_item.items():
            if method == 'parameters' or method.startswith('x-'):
                continue
            tags = op.get('tags') or ['(untagged)']
            domain = tags[0]
            groups[domain].append({
                'path': path,
                'method': method.upper(),
                'op': op,
                'path_params': path_params,
            })
    ordered_domains = [tag['name'] for tag in spec.get('tags', [])]
    for domain in list(groups):
        if domain not in ordered_domains:
            ordered_domains.append(domain)
    ordered: Dict[str, List[Dict[str, Any]]] = {}
    for domain in ordered_domains:
        ops = groups.get(domain)
        if not ops:
            continue
        ordered[domain] = sorted(ops, key=lambda item: (item['path'], item['method']))
    return ordered


def render_markdown(spec: Dict[str, Any], domains: Dict[str, List[Dict[str, Any]]]) -> str:
    lines: List[str] = []
    version = spec.get('info', {}).get('version', 'unversioned')
    lines.append('# Hanko Field API Reference')
    lines.append('')
    lines.append('<!-- AUTO-GENERATED via doc/api/reference/generate_reference.py -->')
    lines.append('')
    lines.append('Comprehensive endpoint catalog derived from `doc/api/api.yaml`. '
                 'Use the generator script whenever the OpenAPI spec changes to keep docs current.')
    lines.append('')
    lines.append(f'*Spec version:* {version}')
    lines.append('')
    lines.extend(render_overview(spec))
    for domain, ops in domains.items():
        lines.append(f'\n## {domain}')
        desc = DOMAIN_DESCRIPTIONS.get(domain, 'Endpoints tagged with this domain in the OpenAPI spec.')
        lines.append(desc)
        lines.append('')
        lines.append(f"- **Default auth:** {DOMAIN_AUTH.get(domain, describe_auth_from_op(spec, ops[0]['op']))}")
        lines.append('')
        for entry in ops:
            lines.extend(render_operation(spec, domain, entry))
    return '\n'.join(lines) + '\n'


def render_overview(spec: Dict[str, Any]) -> List[str]:
    lines: List[str] = []
    servers = spec.get('servers', [])
    primary = servers[0]['url'] if servers else BASE_URL
    lines.append('## Usage & Conventions')
    lines.append('')
    lines.append(f'- Default base URL: `{primary}` (set `$BASE_URL` for curl snippets).')
    lines.append('- All endpoints live under `/api/v1`. Versioning follows semantic release tags.')
    lines.append('- Request/response bodies are JSON encoded in UTF-8 unless noted.')
    lines.append('- Optional query params are omitted from samples for brevity.')
    lines.append('')
    lines.append('### Authentication & RBAC')
    lines.append('')
    lines.append('- Firebase Auth ID tokens back user/staff/admin roles; custom claims carry `role` + optional `scopes` (see `doc/api/security/rbac.md`).')
    lines.append('- `OIDCServer` tokens (IAP / Workload Identity) secure `/internal/*` endpoints for automation.')
    lines.append('- Webhooks require the shared `X-Signature` HMAC header plus rotating secrets via Secret Manager.')
    lines.append('')
    lines.append('### Idempotency')
    lines.append('')
    lines.append('- `Idempotency-Key` header is **required** for `POST`, `PUT`, `PATCH`, and `DELETE`. Middleware deduplicates requests per user+route for 24h.')
    lines.append('- Safe verbs (`GET`, `HEAD`) ignore the header but accept it if present.')
    lines.append('')
    lines.append('### Error Model')
    lines.append('')
    lines.append('- Errors follow the `Error` schema `{ "code": "string", "message": "string", "details": { ... } }`.')
    lines.append('- Typical error codes: `400` validation, `401` unauthenticated, `403` forbidden/missing scope, `404` not found, `409` conflict, `429` throttled, `500` internal.')
    lines.append('- Unless stated otherwise, error payloads are JSON.')
    return lines


def render_operation(spec: Dict[str, Any], domain: str, entry: Dict[str, Any]) -> List[str]:
    path = entry['path']
    method = entry['method']
    op = entry['op']
    title = op.get('summary', 'Untitled')
    desc = op.get('description')
    lines: List[str] = []
    lines.append(f'### `{method} {path}` — {title}')
    if desc:
        lines.append(desc.strip())
    auth_note = DOMAIN_AUTH.get(domain) or describe_auth_from_op(spec, op)
    lines.append(f'- **Auth:** {auth_note}')
    lines.append(f'- **Idempotency:** {describe_idempotency(method)}')
    param_rows = collect_parameters(spec, entry)
    if param_rows:
        lines.append('\n| Name | In | Type | Required | Description |')
        lines.append('| --- | --- | --- | --- | --- |')
        for row in param_rows:
            lines.append('| {display_name} | {loc} | {type} | {req} | {desc} |'.format(**row))
    request_example = None
    body_schema = op.get('requestBody', {}).get('content', {}).get('application/json', {}).get('schema')
    if body_schema:
        request_example = format_json(example_for_schema(spec, body_schema))
        schema_label = schema_name(body_schema) or 'inline'
        lines.append('\n**Request body schema:** `{}`'.format(schema_label))
        lines.append('\n```json\n{}\n```'.format(request_example))
    responses = collect_responses(spec, op)
    success = next((resp for resp in responses if resp['status'].startswith('2')), None)
    if success:
        schema_suffix = f" ({success['schema_name']})" if success['schema_name'] else ''
        lines.append(f"\n**Success response:** `{success['status']}` {success['description']}{schema_suffix}")
        if success['example']:
            lines.append('\n```json\n{}\n```'.format(success['example']))
        elif success['status'] == '204':
            lines.append('\n_No response body_')
    error_entries = [resp for resp in responses if not resp['status'].startswith('2')]
    if error_entries:
        errors = ', '.join(f"`{resp['status']}` {resp['description']}" for resp in error_entries)
        lines.append(f'\n**Error codes:** {errors}')
    lines.append('\n**Sample curl**')
    lines.append('\n```bash\n{}\n```'.format(render_curl(method, path, param_rows, request_example, domain)))
    return lines


def describe_auth_from_op(spec: Dict[str, Any], op: Dict[str, Any]) -> str:
    security = op.get('security', spec.get('security'))
    if not security:
        return 'None'
    options = []
    for option in security:
        option_desc = ' + '.join(option.keys())
        options.append(option_desc)
    return ' or '.join(options)


def describe_idempotency(method: str) -> str:
    if method in IDEMPOTENT_METHODS:
        return 'Required via `Idempotency-Key` header.'
    return 'Not required (safe verb).'


def collect_parameters(spec: Dict[str, Any], entry: Dict[str, Any]) -> List[Dict[str, str]]:
    params: List[Dict[str, Any]] = []
    for param in entry.get('path_params', []):
        params.append(resolve_param(spec, param))
    for param in entry['op'].get('parameters', []):
        params.append(resolve_param(spec, param))
    rows: List[Dict[str, str]] = []
    for param in params:
        schema = resolve_schema(spec, param.get('schema'))
        type_name = infer_schema_type(schema)
        name = param.get('name', '')
        rows.append({
            'raw_name': name,
            'display_name': f'`{name}`',
            'loc': param.get('in', ''),
            'type': type_name,
            'req': 'Yes' if param.get('required') else 'No',
            'desc': (param.get('description') or '').replace('\n', ' ')
        })
    return rows


def resolve_param(spec: Dict[str, Any], param: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(param, dict) and '$ref' in param:
        return resolve_ref(spec, param['$ref']).copy()
    return param


def collect_responses(spec: Dict[str, Any], op: Dict[str, Any]) -> List[Dict[str, Any]]:
    responses: List[Dict[str, Any]] = []
    for status, resp in op.get('responses', {}).items():
        resolved = resolve_response(spec, resp)
        schema = None
        schema_label = None
        example = None
        content = resolved.get('content') or {}
        if 'application/json' in content:
            schema = content['application/json'].get('schema')
        elif content:
            schema = next(iter(content.values())).get('schema')
        if schema:
            schema_label = schema_name(schema)
            example = format_json(example_for_schema(spec, schema))
        responses.append({
            'status': str(status),
            'description': resolved.get('description', ''),
            'schema_name': schema_label,
            'example': example,
        })
    responses.sort(key=lambda item: int(item['status']) if item['status'].isdigit() else 999)
    return responses


def resolve_response(spec: Dict[str, Any], resp: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(resp, dict) and '$ref' in resp:
        return resolve_ref(spec, resp['$ref']).copy()
    return resp


def resolve_schema(spec: Dict[str, Any], schema: Any) -> Any:
    if isinstance(schema, dict) and '$ref' in schema:
        return resolve_ref(spec, schema['$ref'])
    return schema or {}


def schema_name(schema: Any) -> str | None:
    if isinstance(schema, dict):
        ref = schema.get('$ref')
        if ref and ref.startswith('#/components/schemas/'):
            return ref.split('/')[-1]
    return None


def infer_schema_type(schema: Dict[str, Any]) -> str:
    if not schema:
        return 'object'
    typ = schema.get('type')
    if isinstance(typ, list):
        typ = next((t for t in typ if t != 'null'), typ[0] if typ else None)
    if typ == 'array':
        return f"array<{infer_schema_type(schema.get('items', {}))}>"
    if typ:
        return typ
    if 'enum' in schema:
        return 'enum'
    if '$ref' in schema:
        return schema_name(schema) or 'object'
    if 'properties' in schema:
        return 'object'
    return 'string'


def example_for_schema(spec: Dict[str, Any], schema: Any, depth: int = 0) -> Any:
    if depth > MAX_DEPTH or not isinstance(schema, dict):
        return '...'
    if '$ref' in schema:
        # Resolving a component reference does not increase nesting depth.
        return example_for_schema(spec, resolve_ref(spec, schema['$ref']), depth)
    if 'example' in schema:
        return schema['example']
    if 'enum' in schema:
        return schema['enum'][0]
    typ = schema.get('type')
    if isinstance(typ, list):
        typ = next((t for t in typ if t != 'null'), typ[0] if typ else None)
    if typ == 'object' or (not typ and 'properties' in schema):
        props = schema.get('properties', {})
        required = schema.get('required', list(props.keys()))
        result: Dict[str, Any] = {}
        for key in required:
            if key in props:
                result[key] = example_for_schema(spec, props[key], depth + 1)
        for key in props:
            if key in result:
                continue
            if len(result) >= MAX_OBJECT_PROPS:
                break
            result[key] = example_for_schema(spec, props[key], depth + 1)
        if not result and isinstance(schema.get('additionalProperties'), dict):
            result['key'] = example_for_schema(spec, schema['additionalProperties'], depth + 1)
        return result or {}
    if typ == 'array':
        return [example_for_schema(spec, schema.get('items', {'type': 'string'}), depth + 1)]
    if typ == 'integer':
        return 123
    if typ == 'number':
        return 12.34
    if typ == 'boolean':
        return True
    fmt = schema.get('format')
    if fmt == 'date-time':
        return '2024-01-01T00:00:00Z'
    if fmt == 'date':
        return '2024-01-01'
    if fmt == 'uri':
        return 'https://example.com/resource'
    return schema.get('title') or 'string'


def resolve_ref(spec: Dict[str, Any], ref: str) -> Any:
    if not ref.startswith('#/'):
        raise ValueError(f'Unsupported ref: {ref}')
    target: Any = spec
    for part in ref.lstrip('#/').split('/'):
        if isinstance(target, dict) and part in target:
            target = target[part]
        else:
            return {}
    return target


def format_json(obj: Any) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=True)


def render_curl(method: str, path: str, params: List[Dict[str, str]], body_example: str | None, domain: str) -> str:
    headers: List[str] = []
    if domain not in ('Public',):
        if domain == 'Webhooks':
            headers.append('-H "X-Signature: ${SIGNATURE}"')
        elif domain == 'Internal':
            headers.append('-H "Authorization: Bearer ${OIDC_TOKEN}"')
        else:
            headers.append('-H "Authorization: Bearer ${FIREBASE_ID_TOKEN}"')
    if method in IDEMPOTENT_METHODS:
        headers.append('-H "Idempotency-Key: $(uuidgen)"')
    if body_example:
        headers.append('-H "Content-Type: application/json"')
    query = build_query_string(params)
    url = f"$BASE_URL{substitute_path_params(path)}{query}"
    curl_lines = [f"curl -X {method} \"{url}\""]
    for header in headers:
        curl_lines.append(f'  {header}')
    if body_example:
        curl_lines.append("  -d @- <<'JSON'")
        curl_lines.append(body_example)
        curl_lines.append('JSON')
    return '\n'.join(curl_lines)


def build_query_string(params: List[Dict[str, str]]) -> str:
    required_queries = [row for row in params if row['loc'] == 'query' and row['req'] == 'Yes']
    if not required_queries:
        return ''
    query = '&'.join(f"{row['raw_name']}={sample_value_for_param(row['raw_name'])}" for row in required_queries)
    return f'?{query}'


def sample_value_for_param(name: str) -> str:
    if name.endswith('Id'):
        slug = name[:-2] or name
        return f"{slug.lower()}_id"
    if name in ('pageSize', 'limit'):
        return '20'
    if name in ('pageToken', 'cursor'):
        return 'next-token'
    if name == 'lang':
        return 'ja'
    if name == 'since':
        return '2024-01-01T00:00:00Z'
    return name.lower() or 'value'


def substitute_path_params(path: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return sample_value_for_param(match.group(1))

    return re.sub(r'\{([^}]+)\}', repl, path)


if __name__ == '__main__':
    main()
