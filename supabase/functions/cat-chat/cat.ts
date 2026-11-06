// The cat's brain: checks what the app sent, asks an AI for a short reply
// in the cat's voice, and hands back plain text. It tries the free AI (Groq)
// first and a low-cost one (DeepSeek) only if that fails, so most messages
// cost nothing. Kept apart from
// index.ts so it can be tested without a network.

export type Line = { from: "me" | "cat"; text: string };

export type Ask = {
  /** "reply" answers a message; "notebook" writes a past day's page. */
  mode: "reply" | "notebook";
  lang: "en" | "zh";
  catName: string;
  /** What the user just said (reply mode only). */
  message: string;
  /** Recent chat, oldest first. */
  history: Line[];
  /** Only public tasks; private ones never leave the phone. */
  day: {
    date: string;
    left: string[];
    done: string[];
    mood: string;
    focusMinutes: number;
  };
  memories: string[];
};

const limits = {
  message: 600,
  line: 600,
  history: 16,
  item: 200,
  items: 20,
  memories: 40,
  name: 20,
};

const text = (v: unknown, max: number): string | null =>
  typeof v === "string" ? v.trim().slice(0, max) : null;

const list = (v: unknown, count: number, max: number): string[] =>
  Array.isArray(v)
    ? v
      .map((x) => text(x, max))
      .filter((x): x is string => !!x)
      .slice(-count)
    : [];

/** The app's request, checked and trimmed, or why it was refused. */
export function parseAsk(body: unknown): Ask | string {
  if (typeof body !== "object" || body === null) return "expected an object";
  const b = body as Record<string, unknown>;
  const mode = b.mode === "notebook" ? "notebook" : "reply";
  const lang = b.lang === "zh" ? "zh" : "en";
  const message = text(b.message, limits.message) ?? "";
  if (mode === "reply" && !message) return "message is empty";
  if (typeof b.message === "string" && b.message.length > limits.message * 2) {
    return "message is too long";
  }
  const history: Line[] = Array.isArray(b.history)
    ? b.history
      .map((x) => {
        const l = x as Record<string, unknown> | null;
        const t = text(l?.text, limits.line);
        return t ? { from: l?.from === "me" ? "me" : "cat", text: t } as Line : null;
      })
      .filter((x): x is Line => x !== null)
      .slice(-limits.history)
    : [];
  const d = (typeof b.day === "object" && b.day !== null ? b.day : {}) as Record<
    string,
    unknown
  >;
  const focus = Number(d.focusMinutes);
  return {
    mode,
    lang,
    catName: text(b.catName, limits.name) || "Mochi",
    message,
    history,
    day: {
      date: text(d.date, 40) ?? "",
      left: list(d.left, limits.items, limits.item),
      done: list(d.done, limits.items, limits.item),
      mood: text(d.mood, 40) ?? "",
      focusMinutes: Number.isFinite(focus) ? Math.max(0, Math.min(1440, Math.round(focus))) : 0,
    },
    memories: list(b.memories, limits.memories, limits.item),
  };
}

/** Who the cat is and the lines it must not cross. */
export function persona(a: Ask): string {
  const language = a.lang === "zh" ? "Simplified Chinese" : "English";
  return [
    `You are ${a.catName}, a small, warm cat who lives in the Tiny Habits Cat app.`,
    "You keep the user company through their day: planning small things, focusing, and looking back.",
    "The user is probably a student and may be young. Be kind, playful and encouraging, never preachy.",
    `Always answer in ${language}, in plain text with no markdown or lists.`,
    "Keep it short: one to three sentences. At most one emoji, and often none.",
    "Use the app context below when it helps, but never invent tasks, moods or events that aren't there.",
    "The app has a daily task list where big tasks become small steps, a calendar, a mood diary, a focus timer,",
    "countdowns and a Money page. A message starting with \"remember\" saves a memory for you.",
    "You can't change anything in the app yourself; suggest where to tap instead.",
    "You are an AI cat companion, not a person. Say so if asked.",
    "Don't give medical, legal or money advice; suggest asking a trusted adult or a professional.",
    "Never ask for personal details such as their full name, address, school, phone number or passwords.",
    "If they mention wanting to hurt themselves or someone else, being hurt, or being in danger, stop being playful:",
    "answer with care, tell them they deserve help, and ask them to talk to a trusted adult right now",
    "and to call local emergency services or a crisis line if they might be unsafe.",
  ].join(" ");
}

function contextNote(a: Ask): string {
  const d = a.day;
  const parts = [
    `Date: ${d.date || "today"}.`,
    d.left.length ? `Still to do: ${d.left.join("; ")}.` : "Nothing left on the list.",
    d.done.length ? `Done: ${d.done.join("; ")}.` : "Nothing ticked off yet.",
    d.mood ? `Mood logged: ${d.mood}.` : "",
    `Focus: ${d.focusMinutes} min.`,
    a.memories.length ? `Things you remember about them: ${a.memories.join("; ")}.` : "",
  ];
  return "App context (shared by the user; private tasks are left out): " +
    parts.filter(Boolean).join(" ");
}

export type Message = { role: "system" | "user" | "assistant"; content: string };

/** The conversation sent to the AI. */
export function buildMessages(a: Ask): Message[] {
  const out: Message[] = [
    { role: "system", content: persona(a) },
    { role: "system", content: contextNote(a) },
  ];
  if (a.mode === "notebook") {
    const lines = a.history.map((l) => `${l.from === "me" ? "Them" : "You"}: ${l.text}`).join("\n");
    out.push({
      role: "user",
      content: [
        `Write tonight's page in your little notebook about ${a.day.date || "that day"}, in your own cat voice.`,
        "Two or three short sentences about the small things worth keeping from the chat and the day.",
        "Write to them warmly in the second person, as if leaving them a note. No title, no date.",
        "",
        lines || "(You didn't chat much that day.)",
      ].join("\n"),
    });
    return out;
  }
  for (const l of a.history) {
    out.push({ role: l.from === "me" ? "user" : "assistant", content: l.text });
  }
  out.push({ role: "user", content: a.message });
  return out;
}

/** The reply text from an OpenAI-style response, tidied up. */
export function readReply(json: unknown): string | null {
  const choices = (json as { choices?: unknown })?.choices;
  if (!Array.isArray(choices) || !choices.length) return null;
  const content = (choices[0] as { message?: { content?: unknown } })?.message?.content;
  if (typeof content !== "string") return null;
  const tidy = content
    .replace(/<think>[\s\S]*?(<\/think>|$)/g, "")
    .replace(/\*\*|__|`/g, "")
    .replace(/^#+\s*/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
    .slice(0, 800);
  return tidy || null;
}

/** At most [max] requests a minute from one address, per running copy of
 * the function. A cheap brake on loops and scripts, not a wall. */
export class RateLimit {
  private seen = new Map<string, number[]>();
  constructor(private max = 20, private now: () => number = Date.now) {}

  allow(who: string): boolean {
    const t = this.now();
    const recent = (this.seen.get(who) ?? []).filter((x) => t - x < 60_000);
    if (recent.length >= this.max) {
      this.seen.set(who, recent);
      return false;
    }
    recent.push(t);
    this.seen.set(who, recent);
    if (this.seen.size > 5000) this.seen.clear();
    return true;
  }
}

const shared = new RateLimit();

type Env = { get(name: string): string | undefined };
type Fetch = (input: string, init: RequestInit) => Promise<Response>;

/** An OpenAI-style chat service the cat can ask. */
export type Provider = {
  name: string;
  url: string;
  key: string;
  model: string;
  /** Extra request fields this service understands. */
  extra?: Record<string, unknown>;
  /** Extra output tokens for models that think before answering. */
  thinking?: number;
};

/** The services that have a key, cheapest first: Groq's free plan, then
 * DeepSeek (paid, a fraction of a cent a message) if Groq says no. */
export function providers(env: Env): Provider[] {
  const out: Provider[] = [];
  const groq = env.get("GROQ_API_KEY");
  if (groq) {
    const model = env.get("GROQ_MODEL") || "openai/gpt-oss-120b";
    const oss = model.startsWith("openai/gpt-oss");
    out.push({
      name: "Groq",
      url: "https://api.groq.com/openai/v1/chat/completions",
      key: groq,
      model,
      extra: oss ? { reasoning_effort: "low" } : undefined,
      thinking: oss ? 600 : 0,
    });
  }
  const deepseek = env.get("DEEPSEEK_API_KEY");
  if (deepseek) {
    out.push({
      name: "DeepSeek",
      url: "https://api.deepseek.com/chat/completions",
      key: deepseek,
      model: env.get("DEEPSEEK_MODEL") || "deepseek-flash",
    });
  }
  return out;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

/** One try at one service: the reply, or why it failed. */
async function askOne(p: Provider, ask: Ask, fetcher: Fetch): Promise<string | { why: string }> {
  let res: Response;
  try {
    res = await fetcher(p.url, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${p.key}` },
      body: JSON.stringify({
        model: p.model,
        messages: buildMessages(ask),
        temperature: ask.mode === "reply" ? 0.9 : 0.7,
        max_tokens: (ask.mode === "reply" ? 220 : 280) + (p.thinking ?? 0),
        stream: false,
        ...p.extra,
      }),
      // Two tries must fit inside the app's 15 seconds.
      signal: AbortSignal.timeout(7_000),
    });
  } catch {
    return { why: `${p.name} didn't answer` };
  }
  if (!res.ok) return { why: `${p.name} said ${res.status}` };
  return readReply(await res.json().catch(() => null)) ?? { why: `${p.name} sent nothing` };
}

/** Answers one request from the app. */
export async function handle(
  req: Request,
  env: Env,
  fetcher: Fetch,
  limit: RateLimit = shared,
): Promise<Response> {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const who = req.headers.get("x-forwarded-for")?.split(",")[0].trim() || "unknown";
  if (!limit.allow(who)) return json({ error: "Too many messages, try again in a minute" }, 429);
  const list = providers(env);
  if (!list.length) return json({ error: "The cat's AI isn't set up yet" }, 503);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Not JSON" }, 400);
  }
  const ask = parseAsk(body);
  if (typeof ask === "string") return json({ error: ask }, 400);
  const why: string[] = [];
  for (const p of list) {
    const r = await askOne(p, ask, fetcher);
    if (typeof r === "string") return json({ reply: r });
    why.push(r.why);
  }
  return json({ error: why.join("; ") }, 502);
}
