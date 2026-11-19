# Intent: SuppTrack

*Stage 1 (Plan) of the AI-native SDLC. Owner: Nick (product owner and only user). Date: 2026-11-18.*

## Problem
I have many bottles of supplements, plus prescriptions. I can't easily tell:
- which supplements overlap (the same ingredient in several bottles, sometimes adding up to too much), and
- which ones should be taken in the morning or at night, and how far apart from my prescriptions, for them to work as intended.

## Proposed outcome
A personal iPhone app where I scan a bottle's barcode, the app looks up its ingredients, and then it:
- adds up each ingredient across all my bottles and warns me when a daily total is above the official upper limit,
- sorts everything into an AM list and a PM list with checkboxes, and
- tells me when a supplement has to wait for a prescription (for example, 4 hours after a thyroid pill), or when a combination is one to ask my doctor about.

## Affected users and systems
- Users: just me, for now.
- Systems: my iPhone. Public lookup services: NIH Dietary Supplement Label Database (DSLD), NLM RxNorm, Open Food Facts.

## Constraints
- Not medical advice. Show: "Not medical advice. Consult a nutritionally informed physician."
- Some proprietary blends list only the blend's total, not each ingredient's amount.
- Data stays on my phone. No accounts.

## Open questions
- See `docs/spec.md`, section "Open questions".
