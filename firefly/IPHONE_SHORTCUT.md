# iPhone Shortcut: "Log expense"

After this, you can log any receipt photo or payment screenshot from the share
sheet: open it in Photos (or take a screenshot), tap **Share**, tap
**Log expense**, and a notification tells you what was saved, for example
"Logged S$7.40 at Ya Kun Kaya Toast (Food & drink) from DBS."

## Build it (about 3 minutes)

1. Open the **Shortcuts** app, tap **+**, and name it `Log expense`.
2. Tap the **ⓘ** (details) button, turn on **Show in Share Sheet**, and under
   accepted types keep only **Images**. Tap Done.
3. Add the action **Convert Image**. Set it to convert *Shortcut Input* to
   **JPEG**. (iPhone photos are HEIC; the server can read both, but JPEG
   uploads faster.)
4. Add the action **Get Contents of URL**:
   - URL: `http://<your-server>:8082/api/receipt?format=text`
   - Method: **POST**
   - Headers: add `X-Api-Key` with your `RECEIPTS_API_KEY` value
   - Request Body: **File**, and choose the *Converted Image* from step 3
5. Add the action **Show Notification** with the *Contents of URL* as the text.

To also be able to take a photo directly: duplicate the shortcut, name it
`Snap receipt`, and replace step 3's input with a **Take Photo** action. Add it
to your Home Screen or the Action Button.

## What the replies mean

- **Logged …**: saved in Firefly with the image attached.
- **Not saved: I'm not sure about this one …** or **couldn't read the total**:
  open the scanner page (`http://<your-server>:8082`), pick the same image,
  fix the fields and tap Save.
- **This expense is already in Firefly.**: you sent the same purchase twice.
- **Wrong or missing X-Api-Key.**: the header value doesn't match `.env`.
