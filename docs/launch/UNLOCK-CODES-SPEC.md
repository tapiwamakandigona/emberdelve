# Offline signed unlock codes — spec (proposal, v1)

Status: PROPOSED — but ops side is READY. Keypair generated 2026-08-16; the
signing script + private key live outside any repo on the marketing side.
Tapiwa decides; build agent implements the app side.

**Production public key (hex, Ed25519 raw, embed exactly this):**
`38f5e51148855c5690fd5824080e66cac2ac70b6c8ebf1382e26f38f25929aad`

App-side acceptance test: the code below must verify against that key, and
any single-byte change to payload or signature must fail.
`EMBR1.eyJkIjoiMjAyNi0wOC0xNiIsIm4iOiJiZDFiNWVlYSIsInAiOiJlbWJlcl9mb3JnZV91bmxvY2sifQ.1__y7C4NuXeHfsKEe6uw7H6tE9WfkbNmpE71W-hZ5n1FsAfT2rl0VY1Lhy64TcfOyLYoyB75-brplfRXK2uiAg`
(This test code is public and should also be added to a redeemed-nonce
blocklist at build time — `n: bd1b5eea` — so it can't be used as a free
unlock.)
Solves the flagged gap in MARKETING-SYNC.md: GitHub/sideload users have no
way to buy the Ember Forge ($3.99 is Play-billing-only).

## Design goals

- **Fully offline** verification — no server, no account, fits the game's
  "no account, works offline" promise.
- **No new rails**: sales run person-to-person (email + Paynow), the one
  payment path that works from Zimbabwe today.
- Small, auditable, and boring: one keypair, one code format, one screen.

## How it works

1. A single **Ed25519 keypair** exists. The **public key is embedded in the
   app**; the private key lives only on Tapiwa's side (never in any repo).
2. A code is `EMBR1.<base64url(payload)>.<base64url(signature)>` where
   payload is canonical JSON:
   `{"p":"ember_forge_unlock","n":"<8-char nonce>","d":"YYYY-MM-DD"}`
   and signature = Ed25519 over the exact payload bytes.
3. The app's redeem screen (Settings → "Redeem a code") verifies the
   signature against the embedded public key. Valid → set `forgeUnlocked`
   in MetaState (same flag the Play purchase flips) and **store the nonce**
   so re-entry is idempotent. Invalid → honest error, no lockouts.
4. No expiry, no revocation, no device binding in v1. At this scale the
   realistic worst case is a shared code — acceptable; the Forge is priced
   as support, not DRM. Revisit only if abuse is real.

## Sideload Forge-sheet copy (replaces the misleading "Play isn't reachable")

> This build came from GitHub, where Google Play billing isn't available.
> You can unlock the Forge with a code — email tsoro@… and we'll sort it
> out (Paynow, $3.99, human on the other end). Already have a code?
> [Redeem]

## Sales ops (marketing side owns this)

1. Buyer emails → Tapiwa replies with Paynow request for $3.99.
2. On payment, run `sign_unlock_code.py` (reference below) → email the code.
3. Log sale (date, nonce, email) in a private ledger — never in a repo.

## Reference implementation (ops side — already built, shown for review)

```python
# keygen (run ONCE; store private key in a 600-perm file OUTSIDE any repo)
from nacl.signing import SigningKey
sk = SigningKey.generate()
open("unlock_private.key","wb").write(sk.encode())
print("public key (embed in app, hex):", sk.verify_key.encode().hex())

# sign_unlock_code.py
import json, secrets, base64, datetime
from nacl.signing import SigningKey
sk = SigningKey(open("unlock_private.key","rb").read())
payload = json.dumps({"p":"ember_forge_unlock","n":secrets.token_hex(4),
    "d":datetime.date.today().isoformat()}, separators=(",",":"),
    sort_keys=True).encode()
sig = sk.sign(payload).signature
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
print(f"EMBR1.{b64(payload)}.{b64(sig)}")
```

Dart side: `ed25519_edwards` or `cryptography` package; verify signature
over the exact payload bytes, parse JSON only after the signature passes.

## Open questions for Tapiwa

- Price parity with Play ($3.99) or a sideload-supporter price?
- Which contact email goes in the Forge sheet copy?
