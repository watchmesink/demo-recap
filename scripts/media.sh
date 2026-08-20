#!/usr/bin/env bash
# Media helpers for the demo-recap skill.
# Requires: ffmpeg + ffprobe, and the openai-whisper CLI (`whisper`).
# All the fiddly incantations (timestamp-label escaping, GIF palette method,
# webcam-free crops) live here so each run doesn't rediscover them.
set -uo pipefail

FONT="${DEMO_RECAP_FONT:-/System/Library/Fonts/Supplemental/Arial.ttf}"

usage() {
  cat >&2 <<'EOF'
usage: media.sh <command> ...
  lang       <video> [ss] [dur]           ** RUN THIS FIRST ** detect the spoken language on a sample clip
  transcribe <video> <outdir> [model]     English-only path: 16k mono audio + whisper (default small.en)
  translate  <video> <outdir> [src] [model]  non-English path: whisper --task translate -> English
                                          (src = ru/de/... or "auto"; default model: small, multilingual)
  audio      <video> <out.wav>            just extract 16k mono wav
  sheet      <video> <outdir> [iv] [w]    labeled contact sheets, one frame / iv sec (default 30), tiled 5x5
  grab       <video> <ts> <out.jpg>       one full-resolution still at timestamp (ts = HH:MM:SS)
  crop       <video> <ts> <w:h:x:y> <out> one cropped still (use to drop the webcam overlay)
  gif        <video> <start> <dur> <crop|full> <out.gif> [width=1000] [fps=10]
                                          palette-optimized GIF; crop is w:h:x:y or the word "full"
  motion     <video> <start> <dur> <crop|full> <out.jpg>
                                          first+last frame side by side: proves a GIF window really moves
  probe      <video> <ts1> [ts2 ...]      quick tiled preview of frames at the given timestamps
  contact    <out.jpg> <img> [img ...]    label + tile arbitrary images (QA sheet for your final visuals)
  ts         <srt> "<grep pattern>"       print first video timestamp whose caption matches
  pdftext    <pdf> <out.txt>              extract text from a notes/transcript PDF (normalized to prose)
  pdfimages  <pdf> <outdir>               extract embedded screenshots from a notes PDF (e.g. Gemini notes)
Notes:
  - ALWAYS run `lang` before transcribing. Forcing an English-only model (.en) onto
    non-English audio does not error: it emits fluent, confident nonsense.
  - Transcription runs on CPU (reliable). MPS/GPU is avoided (openai-whisper breaks on Apple MPS).
  - `small --task translate` ~= 300-500 frames/s on an idle CPU (55 min audio in ~14 min).
    Don't drop to `base` for translation: it mangles product terms.
EOF
  exit 2
}

cmd="${1:-}"; shift || true
case "$cmd" in
  audio)
    ffmpeg -y -i "$1" -ac 1 -ar 16000 -vn -c:a pcm_s16le "$2" -loglevel error ;;

  lang)
    # Whisper decides the language from one 30s window, so sample from inside the
    # meeting (not the silent intro). Cheap: ~20s of CPU on a 90s clip.
    v="$1"; ss="${2:-}"; dur="${3:-90}"
    if [ -z "$ss" ]; then
      ss=$(python3 -c "
import subprocess,sys
d=float(subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',sys.argv[1]],capture_output=True,text=True).stdout.strip())
s=int(d*0.2); print('%02d:%02d:%02d'%(s//3600,(s%3600)//60,s%60))" "$v")
    fi
    tmp="$(mktemp -d)"
    ffmpeg -y -ss "$ss" -t "$dur" -i "$v" -ac 1 -ar 16000 -vn -c:a pcm_s16le "$tmp/clip.wav" -loglevel error
    echo "sampling at $ss for ${dur}s ..." >&2
    whisper "$tmp/clip.wav" --model small --task translate --device cpu --fp16 False \
      --output_format txt --output_dir "$tmp" --verbose False 2>&1 | grep -i "detected language" || true
    echo "--- sample translation (sanity-check it reads on-topic) ---"
    cat "$tmp/clip.txt" 2>/dev/null | head -12
    rm -rf "$tmp" ;;

  transcribe)
    v="$1"; out="$2"; model="${3:-small.en}"; mkdir -p "$out"
    ffmpeg -y -i "$v" -ac 1 -ar 16000 -vn -c:a pcm_s16le "$out/audio.wav" -loglevel error
    whisper "$out/audio.wav" --model "$model" --language en --device cpu \
      --output_format all --output_dir "$out" --fp16 False --verbose False
    echo "transcript -> $out/audio.txt (+ .srt/.vtt/.tsv/.json)" ;;

  translate)
    # Non-English audio -> English transcript. Multilingual model + --task translate.
    v="$1"; out="$2"; src="${3:-auto}"; model="${4:-small}"; mkdir -p "$out"
    [ -f "$out/audio.wav" ] || ffmpeg -y -i "$v" -ac 1 -ar 16000 -vn -c:a pcm_s16le "$out/audio.wav" -loglevel error
    set -- "$out/audio.wav" --model "$model" --task translate --device cpu \
           --output_format all --output_dir "$out" --fp16 False --verbose False
    [ "$src" = "auto" ] || set -- "$@" --language "$src"
    whisper "$@"
    echo "translated transcript -> $out/audio.txt (+ .srt/.vtt/.tsv/.json)" ;;

  sheet)
    v="$1"; out="$2"; iv="${3:-30}"; w="${4:-620}"; mkdir -p "$out/thumbs"
    ffmpeg -y -i "$v" -vf "fps=1/$iv,scale=$w:-1,drawtext=fontfile='$FONT':text='%{pts\:hms}':x=6:y=6:fontsize=22:fontcolor=yellow:box=1:boxcolor=black@0.6:boxborderw=4" -q:v 4 "$out/thumbs/t_%04d.jpg" -loglevel error
    ffmpeg -y -pattern_type glob -i "$out/thumbs/t_*.jpg" -vf "tile=5x5:margin=6:padding=4:color=white" -q:v 3 "$out/sheet_%02d.jpg" -loglevel error
    echo "contact sheets -> $out/sheet_*.jpg (read them to find demo boundaries / presenters)" ;;

  grab)
    ffmpeg -y -ss "$2" -i "$1" -frames:v 1 -q:v 2 "$3" -loglevel error ;;

  crop)
    ffmpeg -y -ss "$2" -i "$1" -frames:v 1 -vf "crop=$3" -q:v 2 "$4" -loglevel error ;;

  gif)
    v="$1"; ss="$2"; dur="$3"; crop="$4"; out="$5"; width="${6:-1000}"; fps="${7:-10}"
    if [ "$crop" = "full" ]; then cf=""; else cf="crop=$crop,"; fi
    ffmpeg -y -ss "$ss" -t "$dur" -i "$v" -vf "${cf}fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" "$out" -loglevel error
    sz=$(du -h "$out" | cut -f1); echo "$out ($sz)" ;;

  motion)
    # A GIF of a static screen is worthless. Compare the window's first and last
    # frame before committing to it: if they look identical, pick another window.
    v="$1"; ss="$2"; dur="$3"; crop="$4"; out="$5"
    if [ "$crop" = "full" ]; then cf=""; else cf="crop=$crop,"; fi
    end=$(python3 -c "
import sys
h,m,s=[int(x) for x in sys.argv[1].split(':')]; t=h*3600+m*60+s+int(float(sys.argv[2]))
print('%02d:%02d:%02d'%(t//3600,(t%3600)//60,t%60))" "$ss" "$dur")
    tmp="$(mktemp -d)"
    ffmpeg -y -ss "$ss"  -i "$v" -vf "${cf}scale=520:-1" -frames:v 1 "$tmp/a.jpg" -loglevel error
    ffmpeg -y -ss "$end" -i "$v" -vf "${cf}scale=520:-1" -frames:v 1 "$tmp/b.jpg" -loglevel error
    ffmpeg -y -i "$tmp/a.jpg" -i "$tmp/b.jpg" -filter_complex hstack "$out" -loglevel error
    rm -rf "$tmp"; echo "$out  (left = $ss, right = $end; read it — no visible change means no GIF)" ;;

  contact)
    # Label + tile any set of images into one sheet, so you can eyeball every final
    # visual at once (webcam gone? on-topic? readable?) instead of opening them singly.
    out="$1"; shift; tmp="$(mktemp -d)"; i=0; n=$#
    for f in "$@"; do
      i=$((i+1)); lbl=$(basename "$f"); lbl=${lbl//:/\\:}
      ffmpeg -y -i "$f" -vf "scale=520:350:force_original_aspect_ratio=decrease,pad=520:350:(ow-iw)/2:(oh-ih)/2:gray,drawtext=fontfile='$FONT':text='$lbl':x=6:y=5:fontsize=17:fontcolor=yellow:box=1:boxcolor=black@0.7:boxborderw=3" -q:v 3 "$(printf "$tmp/p%03d.jpg" $i)" -loglevel error
    done
    cols=$(python3 -c "import math,sys; print(min(4, max(1, math.ceil(math.sqrt(int(sys.argv[1])))))) " "$n")
    rows=$(python3 -c "import math,sys; print(math.ceil(int(sys.argv[1])/int(sys.argv[2])))" "$n" "$cols")
    ffmpeg -y -i "$tmp/p%03d.jpg" -vf "tile=${cols}x${rows}:color=gray" -frames:v 1 -q:v 3 "$out" -loglevel error
    rm -rf "$tmp"; echo "$out (${cols}x${rows}, $n images) — read it before you ship" ;;

  probe)
    v="$1"; shift; tmp="$(dirname "$v")/.probe.$$"; mkdir -p "$tmp"; i=0
    for t in "$@"; do
      i=$((i+1)); lbl=${t//:/\\:}
      ffmpeg -y -ss "$t" -i "$v" -frames:v 1 -vf "scale=640:-1,drawtext=fontfile='$FONT':text='$lbl':x=6:y=6:fontsize=22:fontcolor=yellow:box=1:boxcolor=black@0.6:boxborderw=4" -q:v 3 "$tmp/$(printf '%03d' $i).jpg" -loglevel error
    done
    ffmpeg -y -pattern_type glob -i "$tmp/*.jpg" -vf "tile=4x3:margin=6:padding=4:color=white" -q:v 3 "$tmp/../probe_grid.jpg" -loglevel error
    echo "probe grid -> $(cd "$tmp/.." && pwd)/probe_grid.jpg" ;;

  ts)
    grep -B1 -i "$2" "$1" | grep -oE '^[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}' | head -1 ;;

  pdftext)
    # Notes/transcript PDFs (e.g. Google/Gemini notes) export justified text as one
    # word per line; collapse whitespace so it reads as prose. Needs pypdf.
    python3 - "$1" "$2" <<'PY'
import re, sys
from pypdf import PdfReader
r = PdfReader(sys.argv[1]); out=[]
for i,p in enumerate(r.pages,1):
    t=re.sub(r'\s+',' ',(p.extract_text() or '')).strip()
    out.append(f"\n\n===== PAGE {i} =====\n{t}")
open(sys.argv[2],"w").write("".join(out))
print("text -> %s (%d pages)" % (sys.argv[2], len(r.pages)))
PY
    ;;

  pdfimages)
    # Gemini/Docs notes often embed the shared-screen screenshots. Pull them out as
    # candidate demo visuals; the caller reads them and crops/renames per demo.
    out="$2"; mkdir -p "$out"
    python3 - "$1" "$out" <<'PY'
import sys, os
from pypdf import PdfReader
r=PdfReader(sys.argv[1]); out=sys.argv[2]; n=0
for pi,page in enumerate(r.pages,1):
    try: imgs=page.images
    except Exception: imgs=[]
    for im in imgs:
        n+=1; ext=im.name.rsplit('.',1)[-1] if '.' in im.name else 'png'
        fn=os.path.join(out,f"p{pi:02d}_{n:03d}.{ext}")
        open(fn,'wb').write(im.data)
        print(f"page {pi}: {len(im.data)//1024}KB -> {os.path.basename(fn)}")
print(f"total images: {n}")
PY
    ;;

  *) usage ;;
esac
