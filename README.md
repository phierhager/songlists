# Melodic / Driving Techno — No Vocals (500 tracks)

Curated in the style of this Spotify playlist: https://open.spotify.com/playlist/2qTmjKrIK4JN6QrQI9QNbG
("Techno" — mostly driving/melodic, mostly instrumental, extended mixes, from
artists like Enrico Sangiuliano, Charlotte de Witte, UMEK, Space 92, Spektre,
Stephan Bodzin, Recondite, etc.)

## Files

- **`tracklist.txt`** — human-readable numbered list (`Artist - Title`).
- **`youtube_urls.txt`** — one entry per line, same order as `tracklist.txt`,
  ready to feed into `yt-dlp -a youtube_urls.txt`. 484 of the 500 lines are
  real, verified `https://www.youtube.com/watch?v=...` links; the other 16
  are `ytsearch1:Artist - Title` locators (see "Known limitations" below).
- **`manifest.tsv`** — `index<TAB>artist<TAB>title<TAB>url`, used by the
  download script to name files cleanly.
- **`download_tracks.sh`** — batch-downloads everything as MP3 via `yt-dlp`.

## How the list was built

All 55 tracks from your Spotify playlist are included (read directly from
the playlist's own data — same artists/titles you'd see on Spotify), plus
445 more tracks in the same style. The extra tracks were sourced from real
Beatport charts, Discogs/Bandcamp album and EP tracklists, Wikipedia, and
artist discographies — not invented from memory — and cross-checked to
exclude anything with lead vocals (a small number of instrumental features,
e.g. a saxophone or spoken sample, were kept since they match your
reference playlist's own style).

Every track was then resolved to an actual YouTube video by querying
YouTube search directly and validating the result (not guessed/fabricated
video IDs). Where a title looked fabricated after failing two independent
search passes, it was dropped and replaced with a freshly-confirmed real
track from the same artist's catalogue, so the final 500 count holds.

## Usage

```bash
chmod +x download_tracks.sh
./download_tracks.sh                       # everything, into ./downloads
OUTPUT_DIR=~/Music/techno ./download_tracks.sh
START=101 END=200 ./download_tracks.sh     # only tracks 101-200
```

Requires `yt-dlp` (`pip install -U yt-dlp`) and `ffmpeg`. Re-running the
script is safe — already-downloaded tracks are skipped via a download
archive file, and failures are logged to `downloads/failed_tracks.txt`.

## Known limitations

- **16 fallback entries.** A handful of tracks (mostly deep cuts from
  Recondite, Massimo Vivona, Sam Paganini, etc., plus a few tracks from
  your original 55) are genuinely real but don't have a strong standalone
  YouTube upload that a search can reliably pin down — YouTube's search
  kept surfacing DJ sets/live streams instead of the studio track. Those
  16 lines use a `ytsearch1:` locator instead of a hardcoded link, so
  `yt-dlp` does its own best-effort search at download time rather than
  risk shipping a confidently wrong URL.
- **YouTube bot-check.** In the sandboxed environment I built this in,
  YouTube blocked actual audio downloads with "Sign in to confirm you're
  not a bot" — common for cloud/datacenter IPs, and likely worsened by the
  ~500 search requests made while resolving this list. I verified every
  link resolves to the correct video, but couldn't do a live end-to-end
  MP3 download test from here. This is very unlikely to affect your own
  machine; if it does, see the troubleshooting note at the top of
  `download_tracks.sh`.
- **yt-dlp/YouTube 403 errors on the actual audio stream** (distinct from
  the bot-check above — this one happens *after* yt-dlp already found the
  video/thumbnail). This is an active, fast-moving cat-and-mouse issue
  between yt-dlp and YouTube (see yt-dlp issues #17456, #17348): certain
  player clients return stream URLs that need a PO token they don't have.
  The script already works around the currently-known-bad client and
  retries with alternates; if you still hit it, run `yt-dlp -U` for the
  latest fix and see the script's troubleshooting comment.
- **"Only images are available for download" / "Requested format is not
  available".** In practice this turned out to be the real blocker in
  testing: yt-dlp needs a JS runtime (deno/node/bun) installed to solve
  YouTube's signature challenges, and without one it can't produce a
  playable audio format on any client. The script now checks for this at
  startup and prints the one-line deno install command if none is found —
  install it and re-run.
- A small number of tracks are remixes/collabs rather than pure originals
  (matching your reference playlist's own style, which also favors
  extended/remix versions).
