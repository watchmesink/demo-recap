---
name: demo-recap
description: Turn a recording of a team demo / showcase / weekly-demo call into a Slack-ready recap that people who missed the call can follow. Transcribes the video, identifies each demo, extracts what was agreed vs left open, adds navigation timestamps, and cuts supporting screenshots/GIFs (with a variety to choose from). Use when given a demo or meeting recording (mp4/mov/m4a/etc.) and asked to summarize it, write a demo recap, produce a shareable/Slack summary, or "extract the main points we agreed on" with screenshots.
---

# Demo recap

Produce a **Slack-ready recap of a team demo call** for people who did not attend. Goal: show progress, surface the still-open questions so they spark discussion in the thread, and keep everyone aligned — readable by someone **outside the team**.

Output is a folder containing `SUMMARY.md` (the post), the supporting screenshots/GIFs named per demo, and the transcript. Follow [references/recap-templates.md](references/recap-templates.md) for the post shape.

Helper script for all media work (encapsulates the ffmpeg/whisper details):
```bash
# point SK at wherever this skill is installed:
SK=~/.claude/skills/demo-recap     # Claude Code
# SK=~/.codex/skills/demo-recap    # Codex
bash "$SK/scripts/media.sh"        # prints usage
```
Prerequisites: `ffmpeg`/`ffprobe` and the `whisper` CLI (openai-whisper). Work in a scratch dir, kept separate from the deliverable folder.

## Workflow

### 0. No video? Work from a notes/transcript PDF
Sometimes there's no usable recording (or only a short pre-call clip) and instead a **meeting-notes PDF** — e.g. Google/Gemini "Notes" — which contains a summary, a full transcript with timestamps, **and embedded screenshots** of the shared screen. Handle it directly:
```bash
bash "$SK/scripts/media.sh" pdftext   "<notes.pdf>" "<work>/notes.txt"     # prose text (summary + transcript)
bash "$SK/scripts/media.sh" pdfimages "<notes.pdf>" "<work>/pdf-images"    # embedded screenshots as candidate visuals
```
Then skip steps 1–2 and go to step 3 using the transcript timestamps already in the PDF. The extracted images are usually one-per-topic screen grabs — read them, crop out any webcam/meet overlay or OS dock (`crop=w:h:x:y`), and rename per demo. Names in a notes PDF are reliable (there's an attendee list) — unlike whisper. Not every topic will have a captured image; say so rather than forcing a mismatched one. If a clip *is* present, sanity-check its real duration first (`ffprobe`) — a 60-min call that reads as 57s is a truncated export, not the recording.

### 1. Check the language, THEN transcribe
Do this before anything else. Recordings from the same team vary: one week's call is Russian, the next week's is English, and a single call can switch between them mid-meeting. On-screen language tells you nothing — the UI and chat content can be Russian while everyone speaks English, and vice versa.

```bash
bash "$SK/scripts/media.sh" lang "<video>"              # samples ~20% in
bash "$SK/scripts/media.sh" lang "<video>" 00:30:00 30  # sample 2-3 more points
```
Sample more than one point; a mixed-language call only shows up if you look twice.

- **Confirmed English** → `transcribe` (uses `small.en`, ≈3× realtime).
- **Anything else, or mixed** → `translate`, which always emits English:
  ```bash
  bash "$SK/scripts/media.sh" translate "<video>" "<work>/transcript" ru   # or "auto"
  ```

Why this order matters: pointing an English-only model (`*.en`) at non-English audio **does not fail**. It returns fluent, confident nonsense — "we have aliens going around", invented product names — and it is easy to waste half an hour before noticing. The reverse mistake is cheap: `--task translate` with the wrong `--language` pin, or over code-switching, still produces a near-identical English transcript, so when unsure prefer `translate`.

`translate` runs ~300–500 frames/s on an idle CPU (55 min of audio in ~14 min). Don't downgrade to `base` for translation — it mangles exactly the product terms the recap depends on ("split button" became "front button").

Transcription is the long pole, so **start it in the background and map the video visually while it runs** (step 2). Output: `audio.txt` + timestamped `audio.srt`. **Read the whole `.txt`** — it's the source of truth. Clean up obvious mis-hearings from context, and never trust its spelling of names.

### 2. Map the meeting visually
```bash
bash "$SK/scripts/media.sh" sheet "<video>" "<work>/sheets" 30
```
Read the resulting `sheet_*.jpg` contact sheets (timecode burned into each frame). Use them to spot: where each demo starts/ends, who is presenting (webcam name labels), which stretches are screen-share vs. gallery/discussion, and candidate screenshot/GIF moments. This visual pass is what lets you attribute demos to the **right, confirmed** presenters.

### 3. Identify the demos and their timestamps
Find boundaries from cue phrases in the transcript — e.g. "let's start with the demos", "the next demo is …", "I want to present …", "does anybody else want to show something?", "another feature I want to show". Then get exact timestamps:
```bash
bash "$SK/scripts/media.sh" ts "<work>/transcript/audio.srt" "present what I did around changes"
```
Record a start–end range per demo (there are usually 2–4).

### 4. Extract what was AGREED vs what's OPEN — and verify it
For each demo, pull: the main idea (in plain terms), the decisions the group converged on, and the questions left unresolved. **Classify strictly:**
- **Agreed** only for clear decisions: "we decided", "our position is", "let's drop it", strong consensus.
- **Open** for anything hedged: "let's think about it", "we have to figure out", "discussable", "out of scope", "maybe", debated-without-resolution.

This agreed-vs-open split is the highest-value and easiest-to-get-wrong part. Verify it against the transcript before writing. When thoroughness matters, run an adversarial check: for each drafted point, re-read the demo's transcript range and confirm a supporting quote exists, reclassifying anything hedged as open. If your agent can run subagents in parallel, extracting each demo independently and then verifying the merged claims works well here.

### 5. Capture the visuals (offer a variety)
For each demo, grab clean stills and short GIFs of the actual on-screen content:
```bash
# still, full frame:
bash "$SK/scripts/media.sh" grab "<video>" 00:38:10 "<work>/shot.jpg"
# still, cropped to DROP THE WEBCAM overlay (1080p full-IDE share ≈ crop 1445:1000:0:80):
bash "$SK/scripts/media.sh" crop "<video>" 00:59:05 "1445:1000:0:82" "<work>/shot.jpg"
# GIF of an interaction (crop or "full"), ~10–15s:
bash "$SK/scripts/media.sh" gif "<video>" 00:38:20 13 "1445:1000:0:80" "<work>/clip.gif"
```
Guidance:
- **Crop out the presenter webcam.** On these 1920×1080 recordings the cam sits to the right of x≈1440, so `crop=1440:1080:0:0` clears it in most layouts. Meet participant tiles and OS control-center overlays need a tighter crop — check, don't assume.
- Prefer moments with real UI on screen (check with `probe`), not talking-head/gallery views.
- **Prove a GIF actually moves before you keep it.** A window that looks lively in a contact sheet is often a static screen with a mouse drifting over it.
  ```bash
  bash "$SK/scripts/media.sh" motion "<video>" 00:45:22 14 "1440:1040:0:40" "<work>/m.jpg"
  ```
  Read the result: identical halves mean pick another window.
- GIFs: ≈900–1000px, 10fps, 10–15s → usually 0.5–3 MB. Text-dense screens (specs, diffs) blow past 10 MB; fix by shortening to ~7s and dropping to 700px/8fps rather than shipping a 10 MB file.
- Static mockups → screenshots; live interactions → GIFs. A Figma walkthrough with no motion gets a still, and say so.
- **Read every final visual as one sheet** before shipping, then keep it in the folder as `_ALL-visuals-preview.jpg`:
  ```bash
  bash "$SK/scripts/media.sh" contact "<out>/_ALL-visuals-preview.jpg" "<out>"/0*.jpg
  ```
- When asked for options, generate several candidates and tile them with `contact` so the user can pick.

### 6. Pick the output format
Ask one question of the context: **how does this reach Slack?**

- **Pasted straight into a Slack message** (the usual case) → write `SUMMARY.txt` as **plain text with zero markdown**. No `#`, no `*`, no backticks, no `[]()`, and no bold anywhere. Markdown markers don't survive the paste and land as visible clutter. Number the sections (`1.`, `2.`), put timestamps in parentheses, prefix open items with `Open:`, and name visuals on their own line as `pic: 02_review.jpg, 02_review.gif`.
- **Posted as a file / kept as a doc** → `SUMMARY.md` per [references/recap-templates.md](references/recap-templates.md), still with no bold.

Either way: a one-line project context for outsiders, acronyms expanded on first use, a timestamp on every section, and a closing invitation to reply in the thread.

Deliverable folder: `~/Downloads/demo-recap-YYYY-MM-DD/` holding the summary, visuals named `NN_topic.jpg` / `NN_topic.gif` keyed to the section numbers, `_ALL-visuals-preview.jpg`, and the transcript (`.txt` + `.srt`).

### 7. Style: short, plain, human
The recap is skimmed by people who skipped the call. Long is worse than incomplete.

- **~60–70 words per demo.** One tight paragraph: what it is, what it does, where it stands. Cut background the reader doesn't need to act on.
- **Open items carry the value** — keep them all, phrased as questions, one line each. Don't compress these to save space; compress the prose instead.
- Short sentences, plain words, active voice. Vary the rhythm.
- **No em dashes, no semicolons, no bold.** Avoid the AI-tell vocabulary: delve, leverage, seamless, robust, comprehensive, crucial, streamline, elevate, "it's worth noting", "dive into". Avoid hedges: basically, essentially, "in order to".
- Prefer concrete over abstract: "tokens burn on buttons nobody clicks" beats "potential efficiency concerns".
- Match the user's spelling (US unless their draft says otherwise) and their section titles if they gave any.
- **Report maturity honestly per section** — not merged yet / in the nightly / ships in the next release / design only / demo failed live. That's the actual progress signal, and it differs wildly between demos in the same call.

### 8. Before you ship
```bash
OUT=<folder>; F="$OUT/SUMMARY.txt"
grep -nE '\*|`|^#|\]\(|—|;' "$F"                              # must be empty for the Slack-paste variant
grep -niE 'delve|leverage|seamless|robust|comprehensive|crucial|streamline|elevate|basically|essentially' "$F"
grep -cE '^[0-9]+\. ' "$F"                                     # section count == number of demos you claim
grep -oE '[0-9]{2}_[a-z-]+\.(jpg|gif)' "$F" | sort -u | while read f; do [ -f "$OUT/$f" ] || echo "MISSING $f"; done
```
Then re-read your own intro line: if it says "eleven demos" and you numbered thirteen, fix it. Confirm each open item against the transcript range one last time — that split is the part most worth getting right.

## Conventions & cautions
- **Names:** the recap works fine without them, so default to leaving presenters out and keeping it about the ideas. If you do attribute, use only a name you read off a webcam label — never whisper's spelling.
- **Honesty about maturity:** see step 7. Include the demo that failed live; it usually explains an open item (a transcription that failed twice is why "add a retry" is on the list).
- **Audience:** outsiders. No internal jargon without a one-line gloss.
- **Undecided = questions.** The point of the recap is to move discussion into the thread.
- **Don't reshape the meeting.** Structure the recap the way the room experienced it. If two topics filled the hour, that's two sections — splitting them into five, or promoting a closing aside into a headline section, makes it read like a different meeting. When the team hands you a decision table or matrix, paste it in rather than describing it in prose.
- **A verbal decision beats your inference.** Mark something agreed only when the transcript says so; a follow-up from the user ("this is the logic we agreed on") outranks whatever the discussion sounded like.
