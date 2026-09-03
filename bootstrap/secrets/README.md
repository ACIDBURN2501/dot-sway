# Secrets

Age-encrypted files, committed to the repo, decrypted per machine by `bootstrap/provision.sh` (stage `secrets`).

- **Identity** is your SSH ed25519 key — age accepts OpenSSH keys natively, so the key you already carry for git is the key that unlocks these files. No GPG, no plugin. If no SSH key is present, `bootstrap-secrets.sh` creates a dedicated age key at `~/.config/sync/age.key` and prints it **once** — back it up.
- **Recovery:** the identity *is* the decryption key, so losing it loses every secret. Back up the SSH private key (or the dedicated `age.key`) somewhere offline, or encrypt each secret to a second recipient (a backup age key) so one lost key does not make the store unrecoverable.
- **Encrypted files** live here as `*.age`; the filename is the decrypted name. Decrypted output lands in `~/.local/share/sync/secrets/` (0600 files, 0700 dir) — never in the repo.
- For structured secrets (multi-key env files), use [sops](https://github.com/getsops/sops) with the same recipient: `sops encrypt --age "$(cat ~/.ssh/id_ed25519.pub)"`.

## Add a secret

```bash
printf '%s' "tskey-…" > /tmp/tailscale_authkey
rage -r "$(cat ~/.ssh/id_ed25519.pub)" /tmp/tailscale_authkey \
  > bootstrap/secrets/tailscale_authkey.age
sha256sum /tmp/tailscale_authkey   # keep the hash somewhere you trust
rm /tmp/tailscale_authkey
```

`tailscale_authkey` (when present) is consumed by the `tailscale` stage on first boot, so a fresh machine joins your tailnet without a keyboard.
