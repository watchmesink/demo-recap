<div align="center">

# demo-recap

> *"The recording is in the channel" is not a recap.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent-Skill-7c3aed)](SKILL.md)
[![Codex](https://img.shields.io/badge/Codex-compatible-111827)](SKILL.md)
[![Claude Code](https://img.shields.io/badge/Claude_Code-compatible-8b5cf6)](SKILL.md)
[![Runs locally](https://img.shields.io/badge/Transcription-local_CPU-16a34a)](#security-and-permissions)

<br>

**An Agent Skill that turns a recording of a demo call into a recap people will actually read: what each demo showed, how mature it is, what the team decided, what is still open, with screenshots and GIFs cut from the video itself.**

Built for product managers, engineering leads, and anyone who runs a recurring demo, showcase, or sprint review and has to report it onward.

<br>

**Install** - pick one:

</div>

**A. With [`skills`](https://github.com/vercel-labs/skills) (any compatible agent):**

```bash
npx skills add watchmesink/demo-recap -g
```

The `-g` flag installs globally at user level so every project can discover it.

**B. Or paste this prompt to your AI agent:**

```text
Install the demo-recap skill for me:

1. Clone https://github.com/watchmesink/demo-recap into my user-level
   skills directory as `demo-recap/`.
   Use the skill directory my agent reads on this machine, for example:
   - Codex: ~/.codex/skills/
   - Claude Code: ~/.claude/skills/
2. Verify that SKILL.md, references/ and scripts/ are present, and that
   scripts/media.sh is executable.
3. Check that ffmpeg, ffprobe and whisper are on PATH, and tell me what is missing.
4. Confirm the install path when done.
```

**C. Manual install paths:**

```bash
# Codex
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
git clone https://github.com/watchmesink/demo-recap.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/demo-recap"

# Claude Code, user-level
mkdir -p "$HOME/.claude/skills"
git clone https://github.com/watchmesink/demo-recap.git \
  "$HOME/.claude/skills/demo-recap"

# Claude Code, project-level
mkdir -p .claude/skills
git clone https://github.com/watchmesink/demo-recap.git \
  .claude/skills/demo-recap
```

<div align="center">

[Use cases](#use-cases) · [What you get](#what-you-get) · [Requirements](#requirements) · [How it works](#how-it-works) · [Philosophy](#philosophy) · [Layout](#layout)

</div>

---

## Use cases

### Case 1 - The weekly demo call, turned into a post

```text
Use demo-recap on ~/Downloads/team-demo.mp4. Plain text, I'm pasting it into Slack.
```

You get a numbered section per demo with a timestamp into the recording, one tight paragraph on what it was and where it stands, its unresolved items as questions, and named screenshots and GIFs to attach.

### Case 2 - Decisions and open questions only

```text
Use demo-recap on this recording, but I only care about what we agreed
and what is still open. Skip the visuals.
```

The skill separates the two strictly. Only explicit decisions count as agreed; anything hedged stays an open question, verified against the transcript before it is written down. That split is the reason to run this on a recording at all.

### Case 3 - A call that is not in English

```text
Use demo-recap on this recording. I think part of it is in another language.
```

The skill samples the audio and detects the spoken language before transcribing, then switches to a translation pass that emits English regardless. This matters because the naive path fails silently, see [Philosophy](#philosophy).

### Case 4 - There is no usable recording, only meeting notes

```text
We didn't record properly. Here's the Gemini notes PDF with the transcript
and screenshots. Can you still make a recap?
```

The skill pulls the prose and the embedded screenshots out of a notes PDF and works from the timestamps already in it.

### Case 5 - Revise a recap you already have

```text
Shorter. And section 2 should be the headline, that's what the room spent
the hour on.
```

The recap is a text file, so it iterates. The skill compresses prose rather than open items, and structures sections the way the meeting actually went instead of the way the video happens to be ordered.

### Other things the skill is good for

- Cutting a clean, webcam-free screenshot or a short GIF out of any screen-share recording.
- Producing a timestamped index of an hour-long call so people can jump to the part they care about.
- Working out which stretches of a recording are screen-share and which are talking heads, before you decide what to clip.

## What you get

A single deliverable folder:

```text
demo-recap-YYYY-MM-DD/
├── SUMMARY.txt                 plain text, ready to paste into Slack
├── 01_bulk-import.jpg          one or two stills per demo, presenter webcam cropped out
├── 01_bulk-import.gif          a short GIF, only where the demo actually moved
├── 02_...
├── _ALL-visuals-preview.jpg    every visual on one sheet, for a last look before sending
└── transcript-EN.txt / .srt    the transcript the recap was written from
```

Each section carries a timestamp into the recording, an honest maturity note (design only, in the nightly, ships next release, not merged yet, demo failed live), and its unresolved items phrased as questions so they can be answered in a thread.

Ask for markdown instead if the recap is going into a document rather than a chat message.

## Requirements

```bash
brew install ffmpeg
pip install -U openai-whisper
pip install -U pypdf          # optional, only for the notes-PDF path
```

Transcription is the slow step and it runs on CPU. Translating a 55 minute call takes roughly 14 minutes on an idle machine, so the skill starts it in the background and maps the video visually while it waits.

## How it works

```text
detect language → transcribe (background) → map video with contact sheets
   → find demo boundaries → split agreed vs open, verified against transcript
   → cut stills and GIFs, motion-checked → assemble → pre-ship checks
```

All the media work sits behind one script with a subcommand per job, so the agent is not improvising ffmpeg invocations:

```bash
bash scripts/media.sh            # prints usage
```

| Command | What it does |
| --- | --- |
| `lang` | Detect the spoken language on a sample clip. Run this first. |
| `transcribe` / `translate` | English path, or non-English to English |
| `sheet` | Timecoded contact sheets of the whole recording |
| `grab` / `crop` | Full-resolution stills, cropped to drop the webcam |
| `gif` | Palette-optimized GIF of an interaction |
| `motion` | First and last frame side by side, to prove a window moves |
| `contact` | Label and tile any images into one QA sheet |
| `ts` | Find the timestamp of a phrase in the transcript |
| `probe` | Quick tiled preview of frames at given timestamps |
| `pdftext` / `pdfimages` | Text and embedded screenshots from a notes PDF |

## What this is

A repeatable way to convert one hour of video into an artifact a team will read, without watching the hour again. It handles the parts that are mechanical but easy to get wrong: language detection, demo boundaries, the agreed-versus-open split, webcam-free crops, GIFs that actually move, and formatting that survives the destination it is pasted into.

## What this is not

- Not a meeting-notes bot. It expects a demo, showcase, or review where things were shown on screen.
- Not a transcription service. The transcript is an input, and the skill assumes you want the *reading* of the meeting, not its text.
- Not a summarizer that flattens everything to bullet points. Maturity and unresolved questions are the payload.
- Not a substitute for asking the presenter. Where the recording is ambiguous, the skill says so rather than inventing a decision.
- Not a way to publish internal material. The deliverable contains transcripts and screenshots of whatever was on screen. Treat the output folder with the same care as the recording.

## Philosophy

Nine rules, each of which exists because ignoring it produced a bad recap:

1. **Check the language before you transcribe.** Pointing an English-only Whisper model at non-English audio does not error. It returns fluent, confident nonsense, and you can lose half an hour before noticing.
2. **Read the pixels, not just the transcript.** Demo boundaries, who presented, and what was actually on screen come from timecoded frames. A transcript alone will mislead you about all three.
3. **Agreed and open are different claims.** Only "we decided" counts as agreed. "Let's think about it" is open. Getting this wrong is the fastest way to make a recap actively harmful.
4. **Prove a GIF moves.** A window that looks lively in a contact sheet is often a static screen with a mouse drifting across it. Compare the first and last frame before keeping it.
5. **Maturity is the progress signal.** "Design mockup" and "in the nightly since yesterday" are the same length and completely different news.
6. **Open items are the payload.** When asked to cut length, compress the prose. Never the questions.
7. **Structure the recap the way the meeting went.** If two topics filled the hour, that is two sections. Splitting them into five, or promoting a closing aside to a headline, makes it read like a different meeting.
8. **Format for the destination.** Markdown markers arrive as visible clutter when a recap is pasted into a chat message. Ask where it is going.
9. **Names are the least reliable thing a transcript gives you.** Attribute only from a legible on-screen label, or leave names out and keep the recap about the ideas.

Read [`SKILL.md`](SKILL.md) first. It is the workflow the agent follows, with the failure modes written next to the step where they bite.

## Layout

```text
demo-recap/
├── README.md                          # this file
├── SKILL.md                           # skill entry point, trigger rules, and the workflow
├── references/
│   └── recap-templates.md             # the plain-text and markdown recap shapes
└── scripts/
    └── media.sh                       # all ffmpeg and whisper work, one subcommand per job
```

## Security and permissions

This skill:

- Reads only the recording you point it at, and writes only into a scratch directory and the deliverable folder.
- Sends nothing to any external service. Transcription runs locally on CPU through the `whisper` CLI, so the audio never leaves the machine.
- Runs `ffmpeg`, `ffprobe`, `whisper`, and `python3`. Python is used only for time arithmetic and the optional PDF path.
- Does not modify the source recording, and needs no credentials or network access.

[`scripts/media.sh`](scripts/media.sh) is a single readable shell script with no network calls. Review it before installing.

## Known limitations

- Whisper is unreliable with names, so the skill deliberately keeps presenter names out unless one is legible on screen.
- Language is detected from samples, so a heavily code-switching call is best handled by the translation path.
- Crop coordinates assume a 1080p screen share with the presenter webcam to one side. Other layouts need a manual crop, which the skill checks by reading the cropped frames back before using them.
- GIF size is bounded by hand. Text-dense screens such as diffs and specs need a shorter or smaller clip.
- Long calls are slow to transcribe on CPU. Budget roughly a quarter of the call's duration.

## About Agent Skills

Agent Skills package a reusable workflow so a compatible agent can discover it, load it only when relevant, and follow it. This repository uses the portable `SKILL.md` entrypoint and works as a Codex skill, a Claude Code skill, or a skill for other Agent-Skill-aware runtimes.

## License

MIT - see [`LICENSE`](LICENSE).
