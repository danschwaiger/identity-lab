# Identity lab

A disposable Docker Compose lab: browser → NGINX → oauth2-proxy → Tyk → demo API, with Keycloak for OIDC and Redis for Tyk. The repository contains configuration and scripts; secrets, certificates and data are local and are not committed.

**Lab only, not production.** Keycloak runs in development mode; Tyk's demo API is keyless; the admin endpoint is reachable through NGINX. Restrict network access to trusted users and the Docker host. NGINX publishes TCP 443 on all host interfaces by default. Anyone with Docker host/network access may bypass the browser-facing authentication path. Do not expose Tyk directly to untrusted clients. Review security and image versions before any wider use.

## Prerequisites

- Linux VM with Docker Engine, Compose plugin, OpenSSL, `sh`, `grep`, `tr`, and `ip`.
- TCP 443 available on the VM, with firewall access limited to trusted workstations.
- A DNS hostname for the lab resolving to the VM from the workstation (DNS or a hosts entry). Use the same hostname everywhere.
- Docker network subnet `172.30.42.0/24` must not overlap an existing network; inspect `ip route` and Docker networks. If necessary, change the Compose subnet, NGINX `ipv4_address`, and oauth2-proxy `--trusted-proxy-ip` consistently.
- Run commands from this repository's root. Compose uses the fixed project name `identity-lab`; do not share that project name with another deployment on the same Docker host. Unset any overriding `COMPOSE_PROJECT_NAME` or `COMPOSE_FILE` environment variables before running the manual Compose commands.

## First setup

1. Clone the repository and change into its directory. Set your DNS hostname and run:

   ```sh
   LAB_HOST=lab.example.test sh setup.sh
   ```

   The script refuses to overwrite existing generated files or named lab volumes. It generates `.env`, a local CA and a server certificate, and starts NGINX, Keycloak, Redis, Tyk and the demo API. It does **not** start oauth2-proxy yet. Failures can leave partial files: inspect them and use the destructive rebuild procedure if appropriate.

2. Check startup:

   ```sh
   docker compose ps
   docker compose logs -f keycloak
   ```

   Press Ctrl+C to stop following the logs. Once services are ready, check the internal gateway route:

   ```sh
   docker compose exec nginx wget -qO- http://tyk:8080/demo/hello
   ```

   Expected: `Hello from the demo API through Tyk!` Startup order does not guarantee Redis is ready; if needed, wait and inspect `docker compose logs --tail=100 redis tyk demo-api`.

3. Copy **only** `certs/lab-ca.crt` to your workstation and import it into the workstation/browser trust store. Never copy or share the CA private key. Open `https://lab.example.test/`, replacing the hostname. Check DNS, firewall and CA trust if needed. Trust only a CA you have verified came from your lab.

4. Configure Keycloak at `https://<your-host>/auth/`:
   - Sign in to the admin console as `admin`. On the VM, `grep '^KC_ADMIN_PASSWORD=' .env` displays the generated password; keep it private and avoid exposing terminal output.
   - Create a realm named `lab`.
   - Create a user such as `alice`, with email `alice@lab.test`, mark the email verified, and set a password. Turn off temporary password if desired. Verification is an administrative assertion, not proof of mailbox ownership.
   - Create an OpenID Connect client named `lab-app`, enable client authentication and Standard flow, and set the **exact** redirect URI to `https://<your-host>/oauth2/callback`. Enable or require PKCE S256 if available.
   - Copy the client secret from the client Credentials tab. Console labels can vary by version.

5. Edit `.env` securely and replace `OAUTH2_PROXY_CLIENT_SECRET=REPLACE_ME` with the client secret. Keep the file private; it contains other secrets too. The secret must be suitable for a Compose dotenv value; use Compose's dotenv quoting rules if it contains special characters. Then start the proxy:

   ```sh
   docker compose up -d oauth2-proxy
   docker compose logs -f oauth2-proxy
   ```

6. Open `https://<your-host>/demo/hello`, sign in as the test user and check for `Hello from the demo API through Tyk!`. To inspect the whole stack:

   ```sh
   docker compose ps
   docker compose logs --tail=100 nginx keycloak oauth2-proxy tyk redis demo-api
   ```
## Stop, restart and rebuild

`docker compose down` stops the stack **without deleting its volumes or local secrets**. `docker compose up -d` restarts the configured lab with its existing data.

For a completely empty rebuild, run:

```sh
LAB_HOST=lab.example.test sh rebuild.sh
```

The script requires you to type `RESET`. It runs `docker compose down --volumes --remove-orphans` for the fixed `identity-lab` project, deletes the local `.env` and entire `certs/` directory, then generates new secrets and a new CA and starts the initial services. **All Keycloak and Redis data in this project's Compose volumes is lost.** This also deletes any other files you put in `certs/`. You must re-import the new CA, recreate the Keycloak realm/user/client, update the new client secret and start oauth2-proxy as above. If the hostname changed, update DNS or your hosts entry. An interrupted or failed rebuild can leave a partial state; inspect it before retrying.

## Troubleshooting

| Symptom | First check |
| --- | --- |
| Browser cannot reach VM | DNS/hosts entry, VM IP, firewall and TCP 443. |
| Certificate warning | Hostname matches certificate; workstation/browser trusts the current lab CA. A rebuild creates a different CA. |
| OAuth proxy cannot discover Keycloak | Keycloak is running, issuer URL is correct, and proxy trusts the lab CA. |
| Invalid redirect URI | Client contains the exact HTTPS callback URI. |
| Login succeeds but access is denied | User email is under `lab.test` and marked verified. |
| Tyk error | Check Redis, Tyk and demo API logs and the internal `wget` test. |

The image tags are versioned but not pinned by digest. Verify the tags and relevant compatibility/security updates in your environment before use. This repository has not been validated against a running Docker environment.
