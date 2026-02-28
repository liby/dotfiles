# Token Efficiency Patterns

Guidelines for reducing token consumption in skills that produce or process data.

## Core Principle

AI does not need human-readable formatting. Choose the most compact representation that preserves meaning.

## Minimize Output Size

- **Flat over nested**: Tabular formats (TSV, CSV, aligned columns) beat nested formats (JSON, XML, YAML) for list data — same information, 60-80% fewer tokens.
- **Header + rows**: A single header row replaces repeated key names on every record.
- **Truncate verbose values**: Dates rarely need full ISO timestamps; descriptions rarely need full text. Trim to what the task actually uses.
- **Strip nulls and empties**: Remove fields with no value before output.
- **Error-first guard**: Check for error responses before transforming data — avoids wasting tokens on malformed output and prevents transform failures.

## Minimize Input Size

- **Request only needed fields**: Most APIs support field selection — use it on every list/search call.
- **Filter server-side**: Apply time ranges, pagination limits, and query filters at the API level, not after fetching everything.
- **Choose the more concise interface**: When both CLI and API are available, pick whichever produces less output for the specific operation. CLI is often more concise for simple reads; APIs offer more control for complex queries.
- **Pipe directly**: Avoid capturing full responses into variables — pipe from source to transform in one step.

## Minimize Context Load

- **Lazy-load references**: List reference files with "use READ tool to load when needed" — do not inline content into SKILL.md. This keeps skill load cost constant.
- **Scope references by topic**: One reference per functional area, self-contained. Only the relevant reference gets loaded.
- **Precompute static data**: Put lookup tables (ID mappings, enum values, config) in reference files rather than requiring runtime API discovery.

## Quick Checklist

1. Is the output the most compact format that preserves meaning?
2. Are API calls requesting only the fields they need?
3. Are references lazy-loaded, not inlined?
4. Do data transforms guard against error responses?
5. Are verbose values (timestamps, descriptions) truncated?
