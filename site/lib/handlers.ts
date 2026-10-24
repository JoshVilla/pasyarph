// Pages Functions for share links. Each file under functions/ is one route
// and calls into here.

import { routeSvg, staticMapUrl } from "./map";
import {
  blockedMessage,
  isAndroid,
  messagePage,
  previewPage,
  respond,
} from "./page";
import { type Env, type LinkKind, fetchPreview } from "./preview";

export interface Context {
  request: Request;
  env: Env;
  params: Record<string, string | string[]>;
}

function param(ctx: Context, name: string): string {
  const v = ctx.params[name];
  return Array.isArray(v) ? v.join("/") : (v ?? "");
}

/** /l/<loop id> and /p/<post id>. */
export async function linkPage(ctx: Context, kind: LinkKind): Promise<Response> {
  const url = new URL(ctx.request.url);
  const android = isAndroid(ctx.request);
  const id = param(ctx, "id");
  const p = await fetchPreview(ctx.env, kind, id);
  if (p == null) {
    return respond(
      messagePage(
        "Couldn't load this link",
        "Pasyar is having trouble right now. Try again in a minute.",
        url,
        android,
      ),
      503,
    );
  }
  const blocked = blockedMessage(p, kind === "post" ? "ride" : "loop");
  if (blocked) {
    return respond(messagePage(blocked.title, blocked.text, url, android), blocked.status);
  }
  return respond(previewPage(ctx.env, kind, id, p, url, android));
}

/** /join/<invite code>: no lookup, invite codes stay between riders. */
export function invitePage(ctx: Context): Response {
  const url = new URL(ctx.request.url);
  return respond(
    messagePage(
      "You're invited",
      "A rider invited you to their club on Pasyar. Get the app, then open this link again to join.",
      url,
      isAndroid(ctx.request),
    ),
  );
}

/** /r/<rider id>: a rider's profile. No lookup: profiles are for
 * signed-in riders only. */
export function riderPage(ctx: Context): Response {
  const url = new URL(ctx.request.url);
  return respond(
    messagePage(
      "A rider on Pasyar",
      "Get Pasyar to see their rides and loops, and ride with them.",
      url,
      isAndroid(ctx.request),
    ),
  );
}

/** /map/l/<id>.png and /map/p/<id>.png: the loop's static map. */
export async function mapImage(ctx: Context, kind: LinkKind): Promise<Response> {
  const id = param(ctx, "id").replace(/\.png$/, "");
  const p = await fetchPreview(ctx.env, kind, id);
  const coords = p?.status === "ok" ? (p.route?.coordinates ?? []) : [];
  if (coords.length < 2) return new Response("Not found", { status: 404 });

  const cache = "public, max-age=86400";
  const key = ctx.env.MAPTILER_KEY;
  if (key) {
    try {
      const res = await fetch(staticMapUrl(coords, key));
      if (res.ok) {
        return new Response(res.body, {
          headers: { "Content-Type": "image/png", "Cache-Control": cache },
        });
      }
      console.log(`maptiler static: HTTP ${res.status}`);
    } catch (e) {
      console.log(`maptiler static: ${e}`);
    }
  }
  return new Response(routeSvg(coords), {
    headers: { "Content-Type": "image/svg+xml", "Cache-Control": cache },
  });
}
