<!--
Thank you for contributing to Zentyal! Please fill in the sections below.
Keep the ChangeLog conventions in mind: each module has a top-level `ChangeLog`
file with tab-indented `+ ` bullets. Add a `HEAD` block at the very top.
-->

## Summary
<!-- One or two sentences describing what this PR does and why. -->

## Related issue(s)
<!-- "Fixes #123", "Refs #456", or "N/A". -->

## Changes
<!-- Bullet list of the main changes, grouped by module if applicable. -->
- 

## Verification
<!-- How did you test this? Reference commands or steps the reviewer can follow. -->
- [ ] `perl -c` passes on every modified `.pm` file
- [ ] Mason templates (`.mas`) reviewed visually
- [ ] Searched the repo for callers of any changed API
- [ ] Built affected module(s) with `zentyal-package` (NOT `dpkg-buildpackage`)
- [ ] Installed and exercised the change on a running system
- [ ] ChangeLog entry added under a `HEAD` block in each affected module's `ChangeLog`

## Checklist
- [ ] No secrets, keys or credentials committed
- [ ] `debian/po/templates.pot` regenerated only if needed (core modules)
- [ ] No commits to generated/transient files unless intentional

## Notes for the reviewer
<!-- Anything the reviewer should pay attention to, or tricky parts of the change. -->
