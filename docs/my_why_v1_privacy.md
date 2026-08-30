# My Why V1 privacy architecture

My Why is a private, client-encrypted journal attached to the authenticated
user's Vision. Text and media are encrypted on the device with AES-256-GCM
before they are sent to Supabase. The AES key is stored through
`flutter_secure_storage`, behind the replaceable `MyWhyKeyStore` abstraction.

Supabase stores ciphertext, nonces, authentication tags, non-sensitive playback
metadata, and private object paths. The `my-why-private` bucket is not public.
Flutter uses authenticated downloads and never creates public or signed URLs for
My Why. Decrypted playback files exist only in the platform temporary directory
and are deleted after playback, replacement, section disposal, or full deletion
where practical.

The database and storage policies restrict normal authenticated access to the
owning user. There are no admin or employee read policies and Flutter contains no
service-role credential. Supabase service-role credentials bypass RLS, however,
so this design should be described as minimizing normal operator access to
plaintext—not as mathematically perfect zero-access or complete end-to-end
privacy against every infrastructure operator.

## Key recovery limitation

V1 encryption is device-bound unless secure key recovery is implemented. The raw
key is never stored in Supabase. Reinstalling the app, clearing secure storage,
or opening My Why on another device can make existing content undecryptable. A
missing key produces an explicit recovery-limitation error; the app does not
silently generate a replacement key for an existing encrypted row.

`MyWhyKeyStore` is intentionally replaceable so a future separately reviewed
multi-device or recovery design can be added without changing encrypted payload
formats. V1 does not implement insecure server-side raw-key recovery.

## Legacy migration

After authenticated access, the client checks `vision_profiles.my_why`. If it is
non-empty and no encrypted text exists, the client encrypts it and confirms the
`my_why_entries` write first. Only then does it clear the legacy plaintext field.
If encrypted text already exists but the old clear previously failed, the client
first verifies that the encrypted text decrypts and then retries clearing the
legacy field. A failed encrypted save never clears the legacy value.

## AI and telemetry boundary

My Why is not loaded by Intelligent Coach services and is never added to prompts.
No transcript is created. The implementation does not log text, keys, media,
signed URLs, storage paths, or ciphertext. If analytics are added later, event
payloads may contain only coarse event names such as `my_why_text_saved`; content
and cryptographic material must remain excluded.
