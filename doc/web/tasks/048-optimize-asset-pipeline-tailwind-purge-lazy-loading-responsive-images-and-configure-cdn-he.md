# Optimize asset pipeline (Tailwind purge, lazy loading, responsive images) and configure CDN headers.

**Parent Section:** 9. Performance, Accessibility, and QA
**Task ID:** 048

## Goal
Optimize asset pipeline for performance and caching.

## Implementation Steps
1. Configure Tailwind purge to remove unused styles; minify CSS/JS.
2. Implement responsive images with `srcset` and lazy loading.
3. Set caching headers and integrate CDN where appropriate.

## Outcome
- Tailwind config now scans Go, template, and markdown sources and safelists dynamic utility patterns to guarantee JIT purge accuracy; production builds run with `NODE_ENV=production`.
- Added reusable responsive image helpers (`responsiveSrcset`, `responsiveSizes`) and applied lazy loading, decoding hints, and size presets across templates. `HANKO_WEB_IMAGE_RESIZE_HOSTS` controls which hosts receive `?width=` variants so we only rely on responsive resizing when the CDN is prepared.
- Static asset middleware now emits `Cache-Control`, `CDN-Cache-Control`, and `Surrogate-Control` headers for week-long caching with stale-while-revalidate, aligning with CDN expectations.
