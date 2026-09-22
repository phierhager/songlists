#!/usr/bin/env bash
#
# download_tracks.sh
#
# Downloads every track in this playlist (see tracklist.txt / youtube_urls.txt)
# as an MP3 using yt-dlp, in the order given in manifest.tsv, and names each
# file "NNN - Artist - Title.mp3" so it sorts the same way as tracklist.txt.
#
# Requirements:
#   - yt-dlp   (pip install -U yt-dlp   /   brew install yt-dlp)
#   - ffmpeg   (needed for MP3 extraction + embedding thumbnail/metadata)
#   - a JS runtime (deno recommended: https://deno.com/) - yt-dlp needs one
#     to solve YouTube's signature/challenge JS; without it you'll see
#     "Signature solving failed" warnings and some formats may be missing.
#
# Usage:
#   ./download_tracks.sh                # downloads everything into ./downloads
#   OUTPUT_DIR=~/Music/techno ./download_tracks.sh
#   START=101 END=200 ./download_tracks.sh    # only download tracks 101-200
#
# Troubleshooting:
#
#   "Sign in to confirm you're not a bot" - YouTube challenging yt-dlp,
#   especially from cloud/VPN IPs. Update yt-dlp first (pip install -U
#   yt-dlp); if it persists, add --cookies-from-browser chrome (or
#   firefox/etc.) to the yt-dlp call below, or export cookies with a
#   browser extension and pass --cookies FILE.
#
#   "unable to download video data: HTTP Error 403: Forbidden" (after it
#   already found the video/thumbnail) - a different, known yt-dlp/YouTube
#   issue: some player clients (notably android_vr, and others as YouTube
#   keeps changing this) return stream URLs that 403 without a PO token.
#   This script already excludes android_vr and retries with alternate
#   clients below. If it still happens: run `yt-dlp -U` to get the latest
#   fix (this is a fast-moving cat-and-mouse game with YouTube - see
#   https://github.com/yt-dlp/yt-dlp/issues/17456 and /issues/17348), and
#   as a last resort add --cookies-from-browser as above, which YouTube
#   generally trusts more than an anonymous session.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.tsv"
URLS_FILE="$SCRIPT_DIR/youtube_urls.txt"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/downloads}"
ARCHIVE_FILE="$OUTPUT_DIR/.download-archive.txt"
START="${START:-1}"
END="${END:-100000}"

# --- sanity checks -----------------------------------------------------
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "ERROR: yt-dlp is not installed or not on PATH." >&2
  echo "Install it with:  pip install -U yt-dlp   (or: brew install yt-dlp / pipx install yt-dlp)" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "WARNING: ffmpeg was not found on PATH. MP3 extraction, thumbnail" >&2
  echo "embedding and metadata tagging need it. Install it (e.g. 'apt install" >&2
  echo "ffmpeg', 'brew install ffmpeg') and re-run for full quality." >&2
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest file not found at $MANIFEST" >&2
  echo "(expected a tab-separated file: index<TAB>artist<TAB>title<TAB>url)" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
touch "$ARCHIVE_FILE"

total=$(wc -l < "$MANIFEST")
ok=0
failed=0
skipped=0
failed_list="$OUTPUT_DIR/failed_tracks.txt"
: > "$failed_list"

echo "Downloading tracks $START-$END of $total into: $OUTPUT_DIR"
echo "(re-running later skips anything already downloaded)"
echo

# --- main loop -----------------------------------------------------------
while IFS=$'\t' read -r idx artist title url; do
  [[ -z "$idx" ]] && continue
  (( idx < START )) && continue
  (( idx > END )) && continue

  num=$(printf "%03d" "$idx")
  safe_name=$(printf "%s - %s" "$artist" "$title" | tr '/\\:*?"<>|' '_')
  out_template="$OUTPUT_DIR/${num} - ${safe_name}.%(ext)s"

  echo "[$idx/$total] $artist - $title"

  common_args=(
    --extract-audio
    --audio-format mp3
    --audio-quality 0
    --embed-thumbnail
    --embed-metadata
    --download-archive "$ARCHIVE_FILE"
    --no-playlist
    --ignore-errors
    --no-abort-on-error
    --sleep-requests 1
    --min-sleep-interval 2
    --max-sleep-interval 5
    -o "$out_template"
  )

  # Primary attempt: default clients minus android_vr, which has a known,
  # currently-active bug returning 403-without-PO-token stream URLs
  # (yt-dlp issues #17456 / #17348). If that still 403s (YouTube's client
  # blocklist shifts often), retry once with an explicit alternate client
  # list before giving up on this track.
  if yt-dlp "${common_args[@]}" \
      --extractor-args "youtube:player_client=default,-android_vr" \
      "$url" \
    || yt-dlp "${common_args[@]}" \
      --extractor-args "youtube:player_client=tv,web_safari" \
      "$url" ; then
    ok=$((ok + 1))
  else
    failed=$((failed + 1))
    echo -e "${idx}\t${artist}\t${title}\t${url}" >> "$failed_list"
    echo "  -> FAILED (logged to $failed_list)"
  fi
done < "$MANIFEST"

echo
echo "Done. ok=$ok failed=$failed"
if [[ -s "$failed_list" ]]; then
  echo "Some tracks failed - see: $failed_list"
  echo "(a track already present in $ARCHIVE_FILE is skipped on re-run, so"
  echo " it's safe to just run this script again to retry the rest)"
fi
