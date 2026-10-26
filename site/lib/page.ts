// The "not installed" web page for share links, styled with the app's
// tokens (design/DESIGN.md): loop name, stats, a static map, store buttons.

import { mapHeight, mapWidth } from "./map";
import {
  type Env,
  type LinkKind,
  type Preview,
  formatDistance,
  formatRideTime,
  photoUrl,
} from "./preview";

export const androidPackage = "com.pasyarph.app";
const playStore = `https://play.google.com/store/apps/details?id=${androidPackage}`;

export function escape(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/**
 * Android: an intent link that opens the installed app (any flavor that
 * verified this site), or the Play Store when there's none. Needed because
 * in-app browsers like Messenger's don't always hand App Links to the app.
 */
export function openInAppUrl(url: URL): string {
  const fallback = encodeURIComponent(playStore);
  return `intent://${url.host}${url.pathname}#Intent;scheme=https;S.browser_fallback_url=${fallback};end`;
}

const styles = `
:root {
  --ink: #15171C; --muted: #5A5F69; --ground: #F3F2EE; --card: #FFFFFF;
  --line: #E2E0DA; --accent: #C2410C; --accent-dark: #9A3412;
  --accent-tint: #FBE9DF; --map-ground: #F7F7F7;
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--ground); color: var(--ink);
  font: 400 16px/1.45 Barlow, system-ui, sans-serif;
}
main { max-width: 480px; margin: 0 auto; padding: 20px 16px 36px; }
.wordmark {
  font: 700 28px/1 "Barlow Condensed", sans-serif; letter-spacing: 1px;
  color: var(--accent); text-decoration: none;
}
.card {
  margin-top: 16px; background: var(--card); border: 1px solid var(--line);
  border-radius: 20px; overflow: hidden;
}
.card-body { padding: 20px; }
.overline {
  margin: 0; font: 700 12px/1.2 Barlow, sans-serif; letter-spacing: .8px;
  text-transform: uppercase; color: var(--accent-dark);
}
h1 {
  margin: 4px 0 0; font: 700 32px/1.1 "Barlow Condensed", sans-serif;
  letter-spacing: .5px; text-transform: uppercase; overflow-wrap: anywhere;
}
.stats { display: flex; gap: 24px; margin-top: 12px; }
.stat b { display: block; font: 700 28px/1 "Barlow Condensed", sans-serif; }
.stat span { font-size: 13px; color: var(--muted); }
.stop { margin: 12px 0 0; color: var(--muted); }
.caption { margin: 12px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; }
.map {
  display: block; width: 100%; height: auto; aspect-ratio: ${mapWidth} / ${mapHeight};
  background: var(--map-ground); border-bottom: 1px solid var(--line);
  object-fit: cover;
}
.actions { display: grid; gap: 10px; margin-top: 20px; }
.btn {
  display: flex; align-items: center; justify-content: center; min-height: 52px;
  border-radius: 14px; font: 700 18px/1 "Barlow Condensed", sans-serif;
  letter-spacing: .6px; text-transform: uppercase; text-decoration: none;
}
.btn-primary { background: var(--accent); color: #fff; }
.btn-secondary { background: var(--card); color: var(--ink); border: 1.5px solid var(--ink); }
.btn-muted { background: var(--ground); color: var(--muted); }
.note { margin: 16px 0 0; font-size: 13px; color: var(--muted); text-align: center; }
`;

interface Page {
  title: string;
  description: string;
  image?: string;
  url: URL;
  body: string;
}

function html(page: Page): string {
  const t = escape(page.title);
  const d = escape(page.description);
  const image = page.image
    ? `<meta property="og:image" content="${escape(page.image)}">
<meta name="twitter:card" content="summary_large_image">`
    : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${t}</title>
<meta name="description" content="${d}">
<meta property="og:site_name" content="Pasyar">
<meta property="og:type" content="website">
<meta property="og:title" content="${t}">
<meta property="og:description" content="${d}">
<meta property="og:url" content="${escape(page.url.href)}">
${image}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;600;700&family=Barlow+Condensed:wght@600;700&display=swap" rel="stylesheet">
<style>${styles}</style>
</head>
<body>
<main>
<a class="wordmark" href="/">PASYAR</a>
${page.body}
</main>
</body>
</html>`;
}

function storeButtons(url: URL, android: boolean): string {
  const open = android
    ? `<a class="btn btn-primary" href="${escape(openInAppUrl(url))}">Open in Pasyar</a>`
    : "";
  return `<div class="actions">
${open}
<a class="btn ${android ? "btn-secondary" : "btn-primary"}" href="${playStore}">Get it on Google Play</a>
<span class="btn btn-muted" aria-disabled="true">App Store · coming soon</span>
</div>`;
}

export function respond(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      // Short: a loop can be renamed, made private or deleted.
      "Cache-Control": "public, max-age=300",
    },
  });
}

/** The page for a public loop or post. */
export function previewPage(
  env: Env,
  kind: LinkKind,
  id: string,
  p: Preview,
  url: URL,
  android: boolean,
): string {
  const name = p.name ?? "A Pasyar loop";
  const stats = [
    p.distance_m != null ? formatDistance(p.distance_m) : null,
    p.duration_s != null ? formatRideTime(p.duration_s) : null,
  ].filter((s): s is string => s != null);
  const mapUrl = `${url.origin}/map/${kind === "post" ? "p" : "l"}/${id}.png`;
  const photo = p.photo ? photoUrl(env, p.photo) : null;
  const by = p.author ? ` · by ${p.author}` : "";
  const club = p.club_name ? ` · ${p.club_name}` : "";
  const description = [
    stats.join(" · "),
    p.main_stop ? `Main stop: ${p.main_stop}` : null,
    "A motorcycle loop on Pasyar.",
  ]
    .filter(Boolean)
    .join(". ");

  const statsHtml = [
    p.distance_m != null
      ? `<div class="stat"><b>${escape(formatDistance(p.distance_m))}</b><span>Distance</span></div>`
      : "",
    p.duration_s != null
      ? `<div class="stat"><b>${escape(formatRideTime(p.duration_s))}</b><span>Ride time</span></div>`
      : "",
  ].join("");

  const body = `<article class="card">
${p.route ? `<img class="map" src="${escape(mapUrl)}" width="${mapWidth}" height="${mapHeight}" alt="Map of ${escape(name)}">` : ""}
<div class="card-body">
<p class="overline">${kind === "post" ? "Ride" : "Loop"}${escape(by)}${escape(club)}</p>
<h1>${escape(name)}</h1>
<div class="stats">${statsHtml}</div>
${p.main_stop ? `<p class="stop">Main stop: ${escape(p.main_stop)}</p>` : ""}
${p.caption ? `<p class="caption">${escape(p.caption)}</p>` : ""}
${storeButtons(url, android)}
<p class="note">Get Pasyar to ride this loop from where you are, with turn-by-turn in Google Maps.</p>
</div>
</article>`;

  return html({
    title: `Pasyar tayo! ${name}${stats.length ? ` · ${stats[0]}` : ""}`,
    description,
    // Chat apps need a PNG: the SVG fallback map only works on the page.
    image: photo ?? (env.MAPTILER_KEY ? mapUrl : undefined),
    url,
    body,
  });
}

/** Club, private, deleted, or an error: a short message and the stores. */
export function messagePage(
  title: string,
  text: string,
  url: URL,
  android: boolean,
): string {
  return html({
    title: `${title} · Pasyar`,
    description: text,
    url,
    body: `<article class="card"><div class="card-body">
<h1>${escape(title)}</h1>
<p class="stop">${escape(text)}</p>
${storeButtons(url, android)}
</div></article>`,
  });
}

/** Title and text for a link that can't be shown, or null when it can. */
export function blockedMessage(
  p: Preview,
  what: "loop" | "ride",
): { title: string; text: string; status: number } | null {
  switch (p.status) {
    case "ok":
      return null;
    case "club":
      return {
        title: `Club ${what}`,
        text: `This ${what} is for members of ${p.club_name ?? "a club"}. Get Pasyar and ask a member for the club's invite link.`,
        status: 200,
      };
    case "private":
      return {
        title: `Private ${what}`,
        text: `Only the rider who made this ${what} can open it.`,
        status: 404,
      };
    default:
      return {
        title: `${what[0].toUpperCase()}${what.slice(1)} not found`,
        text: `This ${what} may have been deleted, or the link is incomplete.`,
        status: 404,
      };
  }
}

export function isAndroid(request: Request): boolean {
  return /android/i.test(request.headers.get("User-Agent") ?? "");
}
