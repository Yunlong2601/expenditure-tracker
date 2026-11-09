# The cat's AI chat (optional, free to start)

Out of the box, the cat in Purrpose answers on the phone with short
built-in replies. This folder adds an optional real AI chat: a small
Supabase Edge Function, `cat-chat`, that asks an AI for the cat's reply. If
the function isn't set up, or can't be reached, the app goes back to the
on-phone replies.

```
phone app ──> Supabase Edge Function (cat-chat) ──> 1. Groq (free plan)
          <── { "reply": "..." }                ──> 2. DeepSeek (low-cost backup, optional)
```

It tries **Groq's free plan** first. Only if Groq says no (for example, the
day's free limit is used up) does it try **DeepSeek**, if you've added a
DeepSeek key. If neither answers, the cat replies on the phone. The keys stay
on Supabase and are never inside the app.

## What it costs

| Part | Cost |
| --- | --- |
| Supabase function | Free plan |
| Groq (first choice) | Free, no card. The free plan allows about 1,000 requests and 200,000 tokens a day, which is roughly 150 cat replies a day for everyone using the app combined |
| DeepSeek (backup, optional) | Prepaid. About US$0.0004 per reply at busy hours and half that off-peak, so US$1 covers roughly 2,500 replies. It can never cost more than you top up |

Prices and limits are from the providers' pages in November 2026 and can
change: see [Groq rate limits](https://console.groq.com/docs/rate-limits) and
[DeepSeek pricing](https://api-docs.deepseek.com/quick_start/pricing).

Gemini's free plan is not used, because Google may use free-plan chats to
improve its products.

## What is sent

Only what the consent note in the app lists:

- the message, and the last 12 chat lines
- the things the cat remembers ("remember …" messages)
- today's **public** tasks, mood and focus minutes

These never leave the phone: private tasks, anything about money (questions
about spending are answered on the phone, and they're left out of the chat
history that is sent), receipts and photos. The function keeps nothing. It
passes the request on and returns the answer. Groq and DeepSeek handle the
text under their own terms and privacy policies, so read them before you
publish the app, especially if young people will use it.

Users see a consent note before their first chat, and are asked again when
an app that used on-phone replies gets the AI. They can turn chat off in
**Me → Account & security**.

## Set it up (about 15 minutes, free)

You need a [Supabase](https://supabase.com) account, a
[Groq](https://console.groq.com) account, and the
[Supabase CLI](https://supabase.com/docs/guides/cli).

1. **Groq key (free).** Sign in at console.groq.com, open *API Keys*, and
   create a key. No card is needed.
2. **Supabase project (free).** Create a project, then, from this
   repository's root:

   ```sh
   supabase login
   supabase link --project-ref <your-project-ref>
   supabase secrets set GROQ_API_KEY=gsk_...
   supabase functions deploy cat-chat
   ```

3. **Build the app with the function's address and the project's anon
   (public) key**, from *Project Settings → API*:

   ```sh
   cd mobile
   flutter build ios --release \
     --dart-define=CAT_AI_URL=https://<your-project-ref>.supabase.co/functions/v1/cat-chat \
     --dart-define=CAT_AI_KEY=<anon key>
   ```

   The same two `--dart-define`s work with `flutter run` and
   `flutter build apk`. Without them the app builds as before, with on-phone
   replies.

If your project only shows the newer *publishable* key (it starts with
`sb_publishable_`), use that as `CAT_AI_KEY` and deploy with
`supabase functions deploy cat-chat --no-verify-jwt`, because that key is
not a JWT.

### Optional: DeepSeek as a backup

When more people use the app than Groq's free plan covers, add DeepSeek so
replies keep coming from the AI instead of the phone:

1. On [platform.deepseek.com](https://platform.deepseek.com), top up a small
   amount (for example US$2) and create an API key.
2. `supabase secrets set DEEPSEEK_API_KEY=sk-...`

No new deploy or app build is needed.

### Optional: other models

- `GROQ_MODEL` picks another Groq model. The default is
  `openai/gpt-oss-120b`. Check that it's on the free plan first.
- `DEEPSEEK_MODEL` picks another DeepSeek model. The default is
  `deepseek-flash`.

Set them with `supabase secrets set NAME=value`.

## Try it

```sh
curl -s https://<your-project-ref>.supabase.co/functions/v1/cat-chat \
  -H "Authorization: Bearer <anon key>" -H "apikey: <anon key>" \
  -H "content-type: application/json" \
  -d '{"message":"I finished my homework!","lang":"en"}'
# {"reply":"..."}
```

Logs are under *Edge Functions → cat-chat → Logs* in the Supabase dashboard.
Supabase can pause free projects that go unused for a while. If the cat
starts answering only on the phone, check that the project is running.

## The cat's rules

`functions/cat-chat/cat.ts` holds the cat's personality and safety rules
(`persona`). In short, the cat:

- answers in the user's chosen language, in one to three plain sentences
- only uses the tasks, moods and memories it was given, and doesn't make up others
- says it is an AI cat if asked
- gives no medical, legal or money advice
- never asks for a full name, address, school, phone number or passwords
- if someone mentions self-harm, being hurt or being in danger, stops being
  playful and points them to a trusted adult, emergency services or a crisis line

Each copy of the function also allows at most 20 messages a minute from one
address, to stop runaway loops. The app waits up to 15 seconds, and the
function gives each AI 7 seconds.

## Develop

```sh
deno test supabase/functions/cat-chat
deno check supabase/functions/cat-chat/index.ts
```

The tests use fake AI services, so they need no keys or network. CI runs them
on every change under `supabase/`.
