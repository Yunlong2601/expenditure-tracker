// Supabase Edge Function: the cat's chat replies and notebook pages.
// Deploy with `supabase functions deploy cat-chat` and set a free Groq key
// with `supabase secrets set GROQ_API_KEY=...` (see supabase/README.md).
import { handle } from "./cat.ts";

Deno.serve((req) => handle(req, Deno.env, fetch));
