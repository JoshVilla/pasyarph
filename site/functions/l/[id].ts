import { type Context, linkPage } from "../../lib/handlers";

export const onRequestGet = (ctx: Context) => linkPage(ctx, "loop");
