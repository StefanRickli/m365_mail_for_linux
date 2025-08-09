# m365_mail_for_linux
PoC to send mails from a M365 account

This will enable applications like `unattended-upgrades` or `raspiBackup` to send mails from a specific e-mail account that lives in the Microsoft 365 world (Office 365 Exchange).

# Installation

**WE WILL REPLACE YOUR INSTALLED VERSION OF `/usr/bin/mail`, make sure that it does not exist yet.**

## Prepare App on Azure

- Go to https://entra.microsoft.com/
- Home > Note "Tenant ID": `TENANT_ID`
- App registrations > New Registration, give it a good name
- Overview > Note the "Application (client) ID": `APPLICATION_ID`
- API permission > Add a permission > Microsoft Graph: Application permissions: Mail.Send
- Grant admin consent for (tenant name)
- Certificates & secrets > Client secrets > New client secret > Name it anythin you like, note the "Value": `CLIENT_SECRET`
- In a PowerShell Terminal:
  - `Install-Module -Name ExchangeOnlineManagement`
  - `New-ApplicationAccessPolicy -AppId "<APPLICATION_ID>" -PolicyScopeGroupId "my_mail@example.com" -AccessRight RestrictAccess -Description "Allow GraphMail app to send as my mailbox only"`
  - `Test-ApplicationAccessPolicy -Identity "my_mail@example.com" -AppId "<APPLICATION_ID>"`


## On Linux Machine

- Install PowerShell globally
  - Untar into `/opt/microsoft/powershell/<version>`, e.g.:
    - `mkdir -p /opt/microsoft/powershell/7.5.2`
    - `tar -xvf powershell-7.5.2-linux-arm64.tar.gz -C /opt/microsoft/powershell/7.5.2`
    - `ln -s /opt/microsoft/powershell/7.5.2/pwsh /usr/bin/pwsh`
- In a root shell:
  - `which mail` **ABORT IF IT RETURNS SOMETHING** (because we will replace it)
  - `cp graph-mail.env.sample /etc/graph-mail.env`
  - `nano /etc/graph-mail.env`, put in your info from above
  - `chmod 600 /etc/graph-mail.env`
  - `cp mail /usr/local/bin/mail`
  - `cp graph-mail /usr/local/bin/graph-mail`
  - `chmod +x /usr/local/bin/mail /usr/local/bin/graph-mail`
  - Test: `echo "Hello World from the Mail shim" | mail -s "Test Subject" my_mail@example.com`
