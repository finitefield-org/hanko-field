# Set up localization, theming, typography, and design tokens shared across screens.

**Parent Section:** 1. Project Setup
**Task ID:** 008

## Goal
Set up localization and theming infrastructure.

## Steps
1. Do not use ARB files. Use Dart class for localization for type safety.
2. Implement localization delegates (`AppLocalizations`) with locale resolution logic.
3. Establish theming system (light/dark), typography scales, and design tokens accessible via providers.
