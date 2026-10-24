import { type Context, invitePage } from "../../lib/handlers";

export const onRequestGet = (ctx: Context) => invitePage(ctx);
