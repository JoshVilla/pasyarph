import { type Context, mapImage } from "../../../lib/handlers";

export const onRequestGet = (ctx: Context) => mapImage(ctx, "loop");
