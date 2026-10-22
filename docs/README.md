# docs/
Working documents from development, written in German and lightly edited for this export (traces of the private repository removed: commit hashes, PR numbers, references to private files; placeholders noted).

Entry points:
- `SSOT.md`: project state as of 2026-09-17. Later changes are not reflected in it.
- `audit-log.md`: chronological log of fixes, decisions and verification rounds, up to 2026-09-17.
- `concept.md`: short stub; the full spec is not included.
- `design/`: design system, palette and mascot specification (`design-system.md` is authoritative).
- The other files are dated decision records and plans (product decisions, bedtime window, snooze concept, build plan, full-app audit, privacy manifest notes).

What is and is not included:
- The documents mention several working files that are not part of this export: the original product spec, review notes, a production-readiness plan, an open-questions list, a next-steps list, research notes, store and privacy-policy drafts, an Apple Developer checklist, a fallback plan, the design handoff, and the mascot illustration briefing and artwork. Most mentions that were kept read "(nicht Teil dieses Exports)"; a few are unmarked, and elsewhere a mention was removed or reduced to a general description.
- References of the form "Plan 3.1" or "v2-Handoff Phase 3" point into the production-readiness plan and the design handoff, which are not included.
- Commit hashes and PR numbers of the private history were removed, together with the sentences that only tracked them. Dates, the test counts and measurements as recorded at the time, and the documents' own ids (findings such as H1 or L25, accepted deviations such as A27, decisions such as B8) were kept. Most of these ids resolve inside this directory (`full-app-audit-2026-09-05.md`, section 8 of `design/design-system.md`, `product-decisions-2026-09-02.md`); ids that come from the review notes (for example C1) do not.

Caveats:
- Placeholders that appear in the documents: `<simulator-udid>`, `<repo>`, `<Projektordner>`, `YOUR_TEAM_ID`, `com.example.*`.
- File and line references (for example `project.yml:92`) are as of the date of the entry that quotes them and have drifted from the exported files.
- `audit-log.md` is mostly chronological; some rounds were back-filled later (for example the block headed "Nachtrag 2026-09-16").
- Some statements are stale. Where documents disagree, the code wins, then later `audit-log.md` entries, then `SSOT.md` (state of 2026-09-17), which in turn replaces the status statements of the older single documents.
