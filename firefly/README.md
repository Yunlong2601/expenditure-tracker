# Firefly III + receipt scanner

This folder turns the expense tracker into a self-hosted setup built on
[Firefly III](https://github.com/firefly-iii/firefly-iii), the open-source money
manager, plus a small add-on that reads receipt photos and screenshots.

```
firefly/
├── firefly-iii/        Firefly III source, pinned to v6.7.9 (git submodule)
├── receipt-scanner/    The add-on: photo or screenshot in, Firefly expense out
├── docker-compose.yml  Runs everything together
├── .env.example        Settings to copy into .env
└── IPHONE_SHORTCUT.md  One-tap "Log expense" from the iPhone share sheet
```

The add-on talks to Firefly through its official REST API instead of changing
Firefly's own code, so Firefly can be upgraded by bumping one version number.
The `firefly-iii/` source is there so you can read it or customise it; the
compose file runs the official image of the same version.

## What you get

| Address | What it is |
| --- | --- |
| `:8080` | Firefly III: accounts, budgets, bills, reports, SGD and CNY side by side |
| `:8081` | Firefly Data Importer: import CSV statements from DBS, OCBC, UOB, and Alipay or WeChat bill exports |
| `:8082` | Receipt scanner: take a photo or pick a screenshot, check what it read, save |

The scanner sends the image to Claude, which reads the shop, total, currency,
date and payment method (English or Chinese, paper receipts or Alipay, WeChat
Pay, PayNow, GrabPay and bank-app screenshots). It then creates a withdrawal in
Firefly, picks the paying account (Alipay purchases go to your Alipay account,
SGD to DBS, and so on), files it under one of your existing categories, tags it
`receipt-scan`, and attaches the image. If it isn't sure, it doesn't save and
asks you to check it on the web page instead. Saving the same receipt twice is
caught as a duplicate.

## Set it up

You need a computer or small server that is always on, with Docker installed.

1. Get the code, including the Firefly source:
   ```sh
   git clone --recurse-submodules https://github.com/Yunlong2601/expenditure-tracker
   cd expenditure-tracker/firefly
   cp .env.example .env
   ```
2. Fill in `.env`. Generate the 32-character values with
   `head -c 24 /dev/urandom | base64`. Leave `FIREFLY_TOKEN` empty for now.
   Get `ANTHROPIC_API_KEY` from [platform.claude.com](https://platform.claude.com).
3. Start it: `docker compose up -d`, then open `http://localhost:8080` and
   register (the first account becomes the admin).
4. In Firefly:
   - **Currencies**: Options > Currencies. Enable CNY. SGD isn't in the default
     list, so add it (code `SGD`, symbol `S$`, 2 decimals) and make it your
     primary currency.
   - **Accounts**: create asset accounts whose names match `ACCOUNT_MAP` and
     `DEFAULT_ACCOUNT` in `.env`, e.g. `DBS` (SGD) and `Alipay` (CNY).
   - **Token**: Options > Profile > OAuth > Personal Access Tokens > Create new
     token. Paste it into `FIREFLY_TOKEN` in `.env`.
5. Apply the token: `docker compose up -d` again.
6. Open `http://<server>:8082`, open **Settings** at the bottom, paste your
   `RECEIPTS_API_KEY`, and scan a receipt.
7. Optional: set up the [iPhone Shortcut](IPHONE_SHORTCUT.md) so you can log
   from any photo or screenshot without opening the page.

### Using it from your phone when you're out

Your phone has to reach the server. The simplest private option is
[Tailscale](https://tailscale.com) (free for personal use) on both the server
and your iPhone; then use the server's Tailscale address in place of
`localhost`. If you put it on the public internet instead, put it behind HTTPS
(for example Caddy or Cloudflare Tunnel) and keep `RECEIPTS_API_KEY` long.

## Cost

Firefly and the importer are free. Reading a receipt with the default model
(`claude-opus-5-5`) costs roughly 1 to 2 US cents, so about US$1 to $2 a month
at 100 receipts. Set `RECEIPT_MODEL=claude-haiku-5-5` in `.env` for a much
cheaper model if accuracy is still good enough for your receipts.

## Upgrading Firefly

Change the version in `docker-compose.yml` (`fireflyiii/core:version-X.Y.Z`),
and to keep the source in step:
`git -C firefly-iii fetch --depth 1 origin tag vX.Y.Z && git -C firefly-iii checkout vX.Y.Z`.

## Developing the scanner

```sh
cd receipt-scanner
pip install -r requirements-dev.txt
pytest
```

API: `POST /api/receipt` with header `X-Api-Key`. Send either a raw image body
(any content type) or a multipart form with a `file` field plus optional
corrected fields (`merchant`, `total`, `currency`, `date`, `category`,
`account`, `summary`). Query options: `save=false` to read without saving,
`format=text` for a one-line reply (used by the Shortcut).
