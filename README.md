# Basic M365 E‑Mail Support on Linux

Send Microsoft 365 (Exchange Online) mail from a Linux box with **no local SMTP server** and **no interactive login**. This project wires a lightweight `mail` wrapper to a PowerShell script that calls the Microsoft Graph `sendMail` endpoint using **app‑only (client credentials) OAuth2**. Result: your cron jobs, unattended‑upgrades, backup scripts, etc., can deliver notifications through your M365 tenant reliably.

---

## Why this is needed (the pain it solves)

- Microsoft is retiring **Basic auth** for SMTP Client Submission; tenants are expected to use **OAuth** or Graph. Many orgs already block basic auth entirely. Traditional `mailx`/`sendmail` flows break in such environments.
- Non‑interactive OAuth for SMTP is awkward; using **Graph app‑only** is the robust path for headless servers.
- This repo gives you a drop‑in `mail` command that talks Graph under the hood.

> TL;DR: Getting M365 mail sending to work on Linux is notoriously fiddly. This project standardizes the setup and makes it repeatable and auditable.

---

## How it works

- **`mail` wrapper**: a tiny Bash script that mimics the standard `mail` command, collects `-s "Subject"` and recipients, reads the body from `stdin`, and invokes the PowerShell sender.
- `graph-mail.ps1`: runs in PowerShell Core, obtains an app‑only access token (client ID/secret, tenant ID) and posts to Microsoft Graph `sendMail` for the configured **sender mailbox**.
- Reads configuration from `/etc/graph-mail.env` for credentials and sender address.
- **No local MTA**: Nothing listens on port 25; messages go straight to Exchange Online over HTTPS.

### What you get

- Works with any tool that pipes to `mail`.
- Plain‑text body out of the box (switchable to HTML in the PS script).
- Defaults to **not** saving to Sent Items (toggleable).

---

## Installation (choose your path)

### A) Debian/Ubuntu on **amd64** (easy path)

1. **Install PowerShell 7** from Microsoft’s repo

Refer to the [official installation documentation](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)

2. **Install the scripts**

```bash
sudo curl -o /usr/local/bin/mail \
  https://raw.githubusercontent.com/StefanRickli/m365_mail_for_linux/main/mail
sudo curl -o /usr/local/bin/graph-mail.ps1 \
  https://raw.githubusercontent.com/StefanRickli/m365_mail_for_linux/main/graph-mail.ps1
sudo chmod +x /usr/local/bin/mail
```

3. **Make it the default `mail`**

Remove/rename any existing `/usr/bin/mail` (from `mailutils`/`bsd-mailx`), then:

```bash
sudo ln -sf /usr/local/bin/mail /usr/bin/mail
```

---

### B) Raspberry Pi / Debian on **ARM** (manual path)

Microsoft doesn’t publish official Debian ARM `.deb` packages for PowerShell. Install from the **binary tarball** and symlink `pwsh`:

1. **Find latest PowerShell version**

```bash
curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep tag_name
```

Note the latest version number (e.g. `v7.4.5`) and strip the leading `v` for use in the next step.

2. **Download the correct tarball** (arm64 for 64‑bit Pi OS; arm32/armhf for 32‑bit):

```bash
PWVER=7.4.5
curl -L -o powershell-linux-arm64.tar.gz \
  https://github.com/PowerShell/PowerShell/releases/download/v$PWVER/powershell-$PWVER-linux-arm64.tar.gz
```

3. **Install PowerShell to /opt and link**

```bash
sudo mkdir -p /opt/microsoft/powershell/$PWVER
sudo tar -xzf powershell-$PWVER-linux-arm64.tar.gz -C /opt/microsoft/powershell/$PWVER
sudo ln -sf /opt/microsoft/powershell/$PWVER/pwsh /usr/bin/pwsh
pwsh --version
```

4. **Install the scripts**

Same procedure as above.

> Tip: For 32‑bit Pi OS, download the `arm32`/`armhf` tarball instead; the rest stays the same. ARM on Debian is **community supported** via tarball.

---

## Azure / M365 setup (what we’re doing and why)

**Goal**: Let a headless server send mail through Exchange Online using **Graph application permissions** (no user sign‑in), **scoped to one mailbox** for least privilege.

1. **App Registration** (Microsoft Entra ID → App registrations)

- Note **Directory (Tenant) ID** and **Application (Client) ID**.
- Create a **Client Secret** (store the value now).
- **API permissions** → **Microsoft Graph** → **Application permissions** → add `Mail.Send` → **Grant admin consent**.

2. **Scope the app to exactly the mailbox(es) you intend** (critical)

- **Preferred (modern)**: **RBAC for Applications in Exchange Online**. Assign an app role limited to a mailbox scope.
- **Classic**: **Application Access Policy**. Create a **mail‑enabled security group**; add the allowed sender mailbox; bind the app to that group.

### Classic: Application Access Policy (example)

```powershell
New-ApplicationAccessPolicy \
  -AppId <YOUR-APP-CLIENT-ID> \
  -PolicyScopeGroupId <MAIL-ENABLED-SEC-GROUP-ADDRESS> \
  -AccessRight RestrictAccess \
  -Description "Limit Graph Mail.Send to alerts mailbox"

Test-ApplicationAccessPolicy \
  -AppId <YOUR-APP-CLIENT-ID> \
  -Identity alerts@yourdomain.com
```

---

## Local configuration

Create `/etc/graph-mail.env`:

```ini
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
APPLICATION_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
CLIENT_SECRET=your-super-secret-value
SENDER=alerts@yourdomain.com
```

Secure it:

```bash
sudo chown root:root /etc/graph-mail.env
sudo chmod 600 /etc/graph-mail.env
```

---

## Usage

```bash
echo "This is the email body." | mail -s "Test email from Linux" recipient@domain.com
```

```bash
echo "Body" | mail -s "Hello" alice@domain.com bob@domain.com
```

Notes:

- `-s` for subject is supported. Sender is fixed in the env file's `SENDER` variable. `-r` ignored.
- Set `$ContentType = "HTML"` in `graph-mail.ps1` for HTML mail.
- Set `saveToSentItems = true` in the JSON payload to save in Sent.

---

## Troubleshooting

- `pwsh: command not found` → check install/symlink.
- `401/403` → check admin consent, mailbox scope, and sender match.
- No email → check spam/quarantine and sender's license/send rights.
- Body/subject missing → ensure you provide `-s` and body via stdin.

