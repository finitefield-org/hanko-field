# API Developer Onboarding

New backend engineers can use this guide to reach a working local environment for the Hanko Field API, including emulators, recurring commands, and common fixes. Keep `doc/api/dev_setup.md`, `doc/api/configuration.md`, `doc/api/testing-matrix.md`, and `doc/api/ci_cd.md` open for deeper reference while following the steps below.

## 1. Access & Credentials Checklist
1. **GitHub + repo access** – confirm you can clone `github.com/hanko-field/hanko-field`.
2. **Google Cloud IAM** – request membership in the `hanko-field-dev` project (reader + Secret Manager accessor). This enables `gcloud auth application-default login`.
3. **Firebase console** – viewer rights let you inspect auth configs that mirror emulator defaults.
4. **Secret Manager references** – ask the platform team for `.secrets.local` bootstrap values (or the dev project secret IDs) if you need to exercise PSP/webhook flows locally.
5. **Stripe test keys** – optional, only needed when hitting payment code paths.

## 2. Required Tooling
| Purpose | Command (macOS/Homebrew) | Notes |
| --- | --- | --- |
| Go 1.21+ | `brew install go` or `asdf install golang 1.21.6` | Match the version pinned in `go.mod`. |
| Taskfile runner | `brew install go-task/tap/go-task` | Optional; `make` works everywhere. |
| Docker Desktop | https://www.docker.com/products/docker-desktop | Required for Firestore emulator + container-based tests. |
| Google Cloud SDK | `brew install --cask google-cloud-sdk` | Provides `gcloud beta emulators firestore`. |
| Firebase CLI | `npm install -g firebase-tools` | Only needed if you prefer `firebase emulators:start`. |
| jq + envsubst | `brew install jq gettext` | Handy for scripting config; used by some helper scripts. |
| Optional: direnv | `brew install direnv` | Automatically loads `.env` when entering the repo. |

After installation run:
```bash
gcloud components install beta
firebase --version  # verify CLI
```

## 3. Repository Bootstrap
```bash
git clone git@github.com:hanko-field/hanko-field.git
cd hanko-field/api
make deps          # installs gofumpt, golangci-lint, staticcheck, govulncheck, gocovmerge
make tidy          # optional: aligns go.mod/go.sum
```
If you use Taskfile:
```bash
cd hanko-field/api
task deps
```

## 4. Configure Local Environment
1. **Authenticate with GCP** (for ADC + emulator tooling):
   ```bash
   gcloud auth application-default login
   gcloud config set project hanko-field-dev
   ```
2. **Create `.env.local` (or `.env`) under `api/`** with the minimum configuration:
   ```ini
   API_FIREBASE_PROJECT_ID=hanko-field-dev
   API_FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
   API_STORAGE_ASSETS_BUCKET=hanko-field-dev-assets
   API_FIREBASE_CREDENTIALS_FILE=$HOME/.config/gcloud/application_default_credentials.json
   API_SECURITY_ENVIRONMENT=local
   GOOGLE_CLOUD_PROJECT=hanko-field-dev
   API_STORAGE_SIGNER_KEY=secret://storage/signer
   API_PSP_STRIPE_API_KEY=secret://stripe/api
   API_PSP_STRIPE_WEBHOOK_SECRET=secret://stripe/webhook
   API_WEBHOOK_SIGNING_SECRET=secret://webhooks/signing
   API_SECRET_FALLBACK_FILE=.secrets.local
   ```
   - The `secret://...` placeholders satisfy the required secret list (`Storage.SignerKey`, `PSP.StripeAPIKey`, `PSP.StripeWebhookSecret`, `Webhooks.SigningSecret`). Populate them either via GCP Secret Manager or the fallback file below.
   - For local-only secrets, place plaintext values in `.secrets.local` (example below) so the resolver can hydrate them without hitting Secret Manager.
     ```ini
     # api/.secrets.local
     secret://storage/signer=@./secrets/dev-storage-signer.json
     secret://stripe/api=sk_test_xxx
     secret://stripe/webhook=whsec_xxx
     secret://webhooks/signing=local-webhook-secret
     ```
3. **Optional direnv**: run `direnv allow` so entering `api/` loads the `.env` file automatically.

## 5. Start Supporting Services (Firestore emulator)
### Option A – Docker one-liner (preferred)
```bash
docker run --rm -p 8080:8080 gcr.io/google.com/cloudsdktool/cloud-sdk:emulators \
  gcloud beta emulators firestore start --host-port=0.0.0.0:8080 --quiet
```
Leave this terminal running. Export variables in a new shell:
```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export GOOGLE_CLOUD_PROJECT=hanko-field-dev
```

### Option B – Firebase CLI
```bash
firebase emulators:start --only firestore --project hanko-field-dev
```
Use the same `FIRESTORE_EMULATOR_HOST` environment variable (`localhost:8080` by default).

Seed data (optional) by running any integration test fixture or helper scripts under `api/internal/internaltest`.

## 6. Run the API Locally
```bash
cd hanko-field/api
make run            # starts cmd/api on :3050
# or
PORT=9090 task run  # Taskfile wrapper
```
- Server respects `.env` values via the configuration loader.
- Visit `http://localhost:3050/healthz` to verify the process.
- Use `CTRL+C` for graceful shutdown.

## 7. Recurring Commands (Linting, Testing, Builds)
| Action | Command | Notes |
| --- | --- | --- |
| Format | `make fmt` / `task fmt` | Runs gofumpt. Use `fmt-check` for CI parity. |
| Lint | `make lint` | golangci-lint + staticcheck. |
| Unit tests | `make test` | No emulator required. |
| Integration tests | `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 make test-integration` | Requires emulator + `GOOGLE_CLOUD_PROJECT`. |
| Full test suite | `make test-ci` | Runs unit + integration consecutively. |
| Coverage | `make cover` | Produces `coverage.unit.out`, `coverage.integration.out`, `coverage.out`. |
| Vulnerability scan | `make vuln` | Wraps `govulncheck`. |
| Build binary | `make build` | Outputs `bin/hanko-api`. |
| Docker parity | `make docker-build && make docker-run` | Builds/runs Cloud Run image locally. |

Running from Taskfile uses the same targets and environment.

## 8. Emulator-Focused Workflows
### Emulator-aware tests
```bash
# Start emulator (see section 5)
cd hanko-field/api
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
GOOGLE_CLOUD_PROJECT=hanko-field-dev \
make test-integration
```
To run a single package:
```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GOOGLE_CLOUD_PROJECT=hanko-field-dev \
  go test -tags=integration ./internal/repositories/firestore -run TestInventoryRepository
```
### Using docker-compose (when available)
Infrastructure will eventually provide `tools/emulators/docker-compose.yml` as referenced in `doc/api/testing-matrix.md`. For now use the Docker one-liner above; once the compose file lands, run `docker compose up firestored` to start all emulators in one command.

## 9. Troubleshooting Guide
| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| `missing required config: API_FIREBASE_PROJECT_ID` on startup | `.env` did not load or key absent | Ensure `.env` lives in `api/`, rerun with `ENV_FILE=.env.local make run`, verify spelling (see `doc/api/configuration.md`). |
| `dial tcp 127.0.0.1:8080: connect: connection refused` during tests | Firestore emulator not running or different port | Start the emulator, or export `FIRESTORE_EMULATOR_HOST=host:port` to match the running instance. |
| `google: could not find default credentials` | No ADC | Run `gcloud auth application-default login`, confirm credentials file path in `.env`. |
| golangci-lint panics about cache permissions | Missing `~/.cache` rights when running inside containers | Set `GOLANGCI_LINT_CACHE=$TMPDIR/golangci-lint` or run `chmod -R 755 ~/.cache`. |
| `docker: address already in use` when starting emulator | Port 8080 occupied | Pass `-p 8085:8080` to the Docker emulator command and update `API_FIRESTORE_EMULATOR_HOST=127.0.0.1:8085`. |
| Tests hang at `Waiting for emulator` | Old emulator container still running | `docker ps` to identify and `docker stop <id>`; ensure only one emulator process is active. |
| `permission denied` when accessing `.secrets.local` | File not created or restricted | Create the file with `chmod 600 .secrets.local`, populate keys, and reference via `API_SECRET_FALLBACK_FILE`. |

## 10. FAQ
**Do I need access to real Firestore/Storage buckets to work locally?**
No. All integration tests target the emulator. Real GCP access is only required for staging smoke tests or when debugging production issues.

**Can I skip Docker and run the emulator via the Firebase CLI?**
Yes—use `firebase emulators:start`. The Docker-based approach matches CI and avoids extra Node dependencies, so it is recommended.

**How are secrets managed locally?**
Use Secret Manager via `gcloud auth application-default login` or provide fallback plaintext values in `.secrets.local`. Never commit `.env`/`.secrets.local` files.

**What is the expected workflow before opening a PR?**
Run `make fmt-check lint test test-integration` (or `make test-ci`) and ensure `make cover` passes if you touched code that affects coverage thresholds. Attach emulator logs for tricky failures.

**Where do I find more operational guidance?**
See `doc/api/ci_cd.md` for pipeline parity, `doc/api/testing-matrix.md` for what each suite covers, and `doc/api/operations/runbooks.md` for incident SOPs.

**How do I mimic Cloud Run locally?**
Build the container via `make docker-build` and run it with `PORT=8080 make docker-run`. Provide env vars with `--env-file` when using `docker run` directly.

## 11. References
- `doc/api/dev_setup.md` – condensed setup commands
- `doc/api/configuration.md` – full environment variable list + secret loading rules
- `doc/api/testing-matrix.md` – what requires emulators vs mocks
- `doc/api/ci_cd.md` – CI parity, Firestore emulator docker command, rollback steps
- `doc/api/manual_qa.md` – when you need to sync with QA for scenario coverage
