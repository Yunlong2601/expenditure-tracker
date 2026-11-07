// Run with: deno test supabase/functions/cat-chat
import { buildMessages, handle, parseAsk, persona, providers, RateLimit, readReply } from "./cat.ts";
import type { Ask } from "./cat.ts";

function ok(cond: unknown, msg = "expected true"): asserts cond {
  if (!cond) throw new Error(msg);
}
function eq<T>(a: T, b: T) {
  const x = JSON.stringify(a), y = JSON.stringify(b);
  if (x !== y) throw new Error(`expected ${y}, got ${x}`);
}

const env = (vars: Record<string, string>) => ({ get: (k: string) => vars[k] });
const post = (body: unknown) =>
  new Request("http://x/cat-chat", {
    method: "POST",
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const deepseek = (content: string, status = 200) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status });

Deno.test("parseAsk keeps a good request and fills defaults", () => {
  const a = parseAsk({ message: "  hi  ", lang: "zh" }) as Ask;
  eq(a.mode, "reply");
  eq(a.lang, "zh");
  eq(a.catName, "Mochi");
  eq(a.message, "hi");
  eq(a.history, []);
  eq(a.day.focusMinutes, 0);
});

Deno.test("parseAsk refuses empty, odd and oversized messages", () => {
  eq(parseAsk(null), "expected an object");
  eq(parseAsk("hi"), "expected an object");
  eq(parseAsk({ message: "   " }), "message is empty");
  eq(parseAsk({ message: "x".repeat(5000) }), "message is too long");
  // A notebook page needs no message.
  ok(typeof parseAsk({ mode: "notebook" }) === "object");
});

Deno.test("parseAsk trims history, lists and numbers", () => {
  const history = Array.from({ length: 30 }, (_, i) => ({
    from: i % 2 ? "cat" : "me",
    text: `line ${i}`,
  }));
  const a = parseAsk({
    message: "hey",
    catName: "A very long cat name that goes on and on",
    history: [...history, { from: "me", text: "" }, null, 7],
    day: { left: [1, "read", "  "], done: "nope", focusMinutes: 99999 },
    memories: Array.from({ length: 60 }, (_, i) => `m${i}`),
  }) as Ask;
  eq(a.history.length, 16);
  eq(a.history.at(-1)!.text, "line 29");
  eq(a.catName.length, 20);
  eq(a.day.left, ["read"]);
  eq(a.day.done, []);
  eq(a.day.focusMinutes, 1440);
  eq(a.memories.length, 40);
  eq(a.memories.at(-1), "m59");
});

Deno.test("persona follows the language and keeps the safety rules", () => {
  const en = persona(parseAsk({ message: "hi", catName: "Mochi" }) as Ask);
  const zh = persona(parseAsk({ message: "hi", lang: "zh" }) as Ask);
  ok(en.includes("You are Mochi"));
  ok(en.includes("in English"));
  ok(zh.includes("Simplified Chinese"));
  ok(en.includes("crisis line"));
  ok(en.includes("not a person"));
  ok(en.includes("Never ask for personal details"));
});

Deno.test("buildMessages sends context, history and the new message", () => {
  const a = parseAsk({
    message: "what's left?",
    history: [{ from: "me", text: "hello" }, { from: "cat", text: "meow" }],
    day: { left: ["read 10 pages"], done: ["drink water"], mood: "happy", focusMinutes: 25 },
    memories: ["likes rainy days"],
  }) as Ask;
  const m = buildMessages(a);
  eq(m.map((x) => x.role), ["system", "system", "user", "assistant", "user"]);
  ok(m[1].content.includes("read 10 pages"));
  ok(m[1].content.includes("drink water"));
  ok(m[1].content.includes("likes rainy days"));
  ok(m[1].content.includes("25 min"));
  eq(m.at(-1)!.content, "what's left?");
});

Deno.test("buildMessages asks for a notebook page in notebook mode", () => {
  const a = parseAsk({
    mode: "notebook",
    day: { date: "2026-11-05" },
    history: [{ from: "me", text: "I finished my essay" }],
  }) as Ask;
  const m = buildMessages(a);
  eq(m.length, 3);
  eq(m[2].role, "user");
  ok(m[2].content.includes("notebook"));
  ok(m[2].content.includes("2026-11-05"));
  ok(m[2].content.includes("Them: I finished my essay"));
});

Deno.test("readReply tidies markdown and rejects junk", () => {
  eq(readReply({ choices: [{ message: { content: "## **Hi** there `cat`" } }] }), "Hi there cat");
  eq(readReply({ choices: [{ message: { content: "   " } }] }), null);
  eq(readReply({ choices: [] }), null);
  eq(readReply(null), null);
  eq(readReply({ choices: [{ message: { content: "x".repeat(2000) } }] })!.length, 800);
});

Deno.test("readReply drops a model's thinking", () => {
  eq(readReply({ choices: [{ message: { content: "<think>hmm</think>Meow!" } }] }), "Meow!");
  eq(readReply({ choices: [{ message: { content: "<think>never finished" } }] }), null);
});

Deno.test("providers lists free Groq first, then DeepSeek", () => {
  eq(providers(env({})), []);
  const both = providers(env({ GROQ_API_KEY: "g", DEEPSEEK_API_KEY: "d" }));
  eq(both.map((p) => p.name), ["Groq", "DeepSeek"]);
  eq(both.map((p) => p.model), ["openai/gpt-oss-120b", "deepseek-flash"]);
  eq(both[0].extra, { reasoning_effort: "low" });
  const own = providers(env({ GROQ_API_KEY: "g", GROQ_MODEL: "qwen/qwen3-32b", DEEPSEEK_MODEL: "x" }));
  eq(own[0].model, "qwen/qwen3-32b");
  eq(own[0].extra, undefined);
  eq(own.length, 1);
});

Deno.test("handle only takes POST and needs a key", async () => {
  const never = () => Promise.reject(new Error("should not call"));
  const k = env({ GROQ_API_KEY: "k" });
  eq((await handle(new Request("http://x"), k, never, new RateLimit())).status, 405);
  eq((await handle(post({ message: "hi" }), env({}), never, new RateLimit())).status, 503);
  eq((await handle(post("{nope"), k, never, new RateLimit())).status, 400);
  eq((await handle(post({ message: "" }), k, never, new RateLimit())).status, 400);
});

Deno.test("handle asks the free AI first and returns its reply", async () => {
  const calls: { url: string; auth: string; body: Record<string, unknown> }[] = [];
  const res = await handle(
    post({ message: "hi", lang: "en" }),
    env({ GROQ_API_KEY: "free", DEEPSEEK_API_KEY: "paid" }),
    (url, init) => {
      calls.push({
        url,
        auth: new Headers(init.headers).get("authorization") ?? "",
        body: JSON.parse(String(init.body)),
      });
      return Promise.resolve(deepseek("Meow, hello!"));
    },
    new RateLimit(),
  );
  eq(res.status, 200);
  eq(await res.json(), { reply: "Meow, hello!" });
  eq(calls.length, 1);
  eq(calls[0].url, "https://api.groq.com/openai/v1/chat/completions");
  eq(calls[0].auth, "Bearer free");
  eq(calls[0].body.model, "openai/gpt-oss-120b");
  eq(calls[0].body.reasoning_effort, "low");
  eq(calls[0].body.stream, false);
});

Deno.test("handle falls back to DeepSeek when the free AI says no", async () => {
  const urls: string[] = [];
  const res = await handle(
    post({ message: "hi" }),
    env({ GROQ_API_KEY: "free", DEEPSEEK_API_KEY: "paid" }),
    (url, init) => {
      urls.push(url);
      if (url.includes("groq")) return Promise.resolve(new Response("{}", { status: 429 }));
      eq(JSON.parse(String(init.body)).model, "deepseek-flash");
      eq("reasoning_effort" in JSON.parse(String(init.body)), false);
      return Promise.resolve(deepseek("Backup meow"));
    },
    new RateLimit(),
  );
  eq(await res.json(), { reply: "Backup meow" });
  eq(urls, ["https://api.groq.com/openai/v1/chat/completions", "https://api.deepseek.com/chat/completions"]);
});

Deno.test("handle works with only DeepSeek set up", async () => {
  let model = "";
  const res = await handle(
    post({ message: "hi" }),
    env({ DEEPSEEK_API_KEY: "k", DEEPSEEK_MODEL: "deepseek-other" }),
    (_u, init) => {
      model = JSON.parse(String(init.body)).model;
      return Promise.resolve(deepseek("ok"));
    },
    new RateLimit(),
  );
  eq(res.status, 200);
  eq(model, "deepseek-other");
});

Deno.test("handle reports failures without leaking keys", async () => {
  const k = env({ GROQ_API_KEY: "secret1", DEEPSEEK_API_KEY: "secret2" });
  const down = await handle(post({ message: "hi" }), k, () => Promise.reject(new Error("net")), new RateLimit());
  eq(down.status, 502);
  const refused = await handle(post({ message: "hi" }), k, () =>
    Promise.resolve(new Response("{}", { status: 401 })), new RateLimit());
  eq(refused.status, 502);
  const blank = await handle(post({ message: "hi" }), k, () => Promise.resolve(deepseek("")), new RateLimit());
  eq(blank.status, 502);
  for (const r of [down, refused, blank]) {
    const text = await r.text();
    ok(!text.includes("secret"), "key leaked");
    ok(text.includes("Groq") && text.includes("DeepSeek"), "says what failed");
  }
});

Deno.test("RateLimit lets 20 a minute through from one address", () => {
  let t = 0;
  const limit = new RateLimit(20, () => t);
  for (let i = 0; i < 20; i++) ok(limit.allow("a"));
  ok(!limit.allow("a"));
  ok(limit.allow("b"), "other addresses are separate");
  t = 61_000;
  ok(limit.allow("a"), "a minute later it opens again");
});

Deno.test("handle answers 429 when one address sends too much", async () => {
  const limit = new RateLimit(1);
  const k = env({ GROQ_API_KEY: "k" });
  const from = (ip: string) =>
    new Request("http://x", {
      method: "POST",
      headers: { "x-forwarded-for": `${ip}, 10.0.0.1` },
      body: JSON.stringify({ message: "hi" }),
    });
  const reply = () => Promise.resolve(deepseek("ok"));
  eq((await handle(from("1.1.1.1"), k, reply, limit)).status, 200);
  eq((await handle(from("1.1.1.1"), k, reply, limit)).status, 429);
  eq((await handle(from("2.2.2.2"), k, reply, limit)).status, 200);
});
