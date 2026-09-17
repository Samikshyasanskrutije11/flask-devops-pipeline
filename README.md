# Flask DevOps Pipeline —
Python → Docker → Jenkins → Terraform → AWS EC2

A complete, automated path from source code to a running server on the internet: a
Python/Flask application that is tested, containerised with Docker, built and deployed
by a Jenkins CI/CD pipeline, onto AWS infrastructure provisioned entirely with Terraform.

The app itself is intentionally simple. The point of this project is everything **around**
it — the same release pipeline shape used in production systems, scaled down to something
you can read end to end in one sitting.

---

## What it does

Every `git push` to this repository can trigger a fully automated release:

```
git push  →  Jenkins triggered
          →  tests + lint run
          →  Docker image built and smoke-tested
          →  image pushed to Docker Hub
          →  Terraform provisions / updates the EC2 server
          →  Jenkins SSHes in and deploys the new image
          →  /health checked on the live URL
          →  done — live at http://<ec2-public-ip>
```

If any stage fails, the pipeline stops there. A broken build never reaches AWS.

---

## Architecture

```
 GitHub push
     │  (webhook)
     ▼
 ┌──────────┐
 │ Jenkins  │
 └────┬─────┘
      │
      ├─▶ 1. pytest + flake8            (fail fast on bad code)
      │
      ├─▶ 2. docker build               (image tagged :BUILD_NUMBER and :latest)
      │
      ├─▶ 3. smoke test the image       (run container, poll /health)
      │
      ├─▶ 4. docker push                (Docker Hub)
      │
      ├─▶ 5. terraform apply            (creates/updates AWS EC2 + security group)
      │
      ├─▶ 6. ssh deploy                 (pull image, restart container on EC2)
      │
      └─▶ 7. verify                     (poll http://<ec2-ip>/health)
                                                │
                                                ▼
                                     Live Flask app on AWS EC2
```

## How each layer works

### 1. Application layer — Flask
A small Flask app exposing three routes:

| Route | Purpose |
|---|---|
| `GET /` | HTML landing page showing app version, environment, and container hostname |
| `GET /health` | JSON liveness probe — polled by Docker's `HEALTHCHECK` and by Jenkins after every deploy |
| `GET /api/info` | JSON metadata: version, environment, hostname, Python version, timestamp |

`/health` isn't decorative — it's the single source of truth the rest of the pipeline uses
to decide whether a build or a deployment actually succeeded.

### 2. Testing — pytest + flake8
A pytest suite checks that each route returns the correct status code and payload; flake8
lints the code for style issues. This runs **before** anything is built into an image, so
the pipeline never wastes time containerising or deploying broken code.

### 3. Containerisation — Docker
The app and its dependencies are packaged into a Docker image using a `python:3.11-slim`
base. Key choices in the `Dockerfile`:
- dependencies are installed in their own layer *before* app code is copied in, so Docker
  can cache that layer and rebuilds are fast when only source files change
- the container runs as a **non-root** user, not root
- a `HEALTHCHECK` instruction lets Docker itself detect an unhealthy container
- the app is served by Gunicorn (2 workers) rather than Flask's own dev server

The resulting image runs identically on a laptop, the Jenkins agent, or AWS — that
consistency is the entire reason to containerise in the first place.

### 4. CI/CD — Jenkins
A declarative `Jenkinsfile` defines 8 pipeline stages, run in order on every push:

1. **Checkout** — pull the latest commit
2. **Install & Test** — venv, `flake8`, `pytest` (results published as a JUnit report in Jenkins)
3. **Build Docker Image** — tagged both `:$BUILD_NUMBER` (immutable, rollback-able) and `:latest`
4. **Smoke Test Image** — runs the freshly built image, polls `/health`, then tears it down
5. **Push to Docker Hub** — authenticates with stored credentials, pushes both tags
6. **Terraform Provision** — `init` / `validate` / `plan` / `apply` against AWS
7. **Deploy to EC2** — SSH into the server, pull the new image, replace the running container
8. **Verify Deployment** — polls the live public IP's `/health` and fails the build if it doesn't come up healthy

Credentials (Docker Hub, AWS keys, SSH key) are all pulled from Jenkins' credential store
at runtime — none of them ever touch the repository.

### 5. Infrastructure as Code — Terraform
Rather than clicking through the AWS console, the server's entire definition lives in `.tf`
files under `terraform/`:
- looks up the latest Ubuntu 22.04 AMI dynamically (never a hard-coded, staling AMI ID)
- defines a security group allowing HTTP (port 80) from anywhere and SSH (port 22) only
  from a CIDR you choose
- provisions a `t2.micro` EC2 instance whose `user_data.sh` boot script installs Docker
  automatically on first launch
- outputs the instance's public IP, ready-made SSH command, and app URL

Because the infrastructure is defined in code, `terraform apply` produces the exact same
environment every time, changes to it are reviewable like any other code change, and
`terraform destroy` tears everything down cleanly when it's no longer needed.

### 6. Deployment target — AWS EC2
Once Terraform has the server running with Docker installed, Jenkins connects over SSH,
pulls the image it just pushed to Docker Hub, stops whatever container was previously
running, and starts the new one on port 80. The live app updates with no manual server
work involved.

---

## Repository layout

```
flask-devops-pipeline/
├── app/
│   ├── app.py                  # Flask app factory + routes
│   ├── wsgi.py                 # Gunicorn entrypoint
│   ├── requirements.txt        # runtime deps
│   ├── requirements-dev.txt    # test/lint deps
│   └── templates/index.html    # landing page
├── tests/test_app.py           # pytest suite
├── Dockerfile                  # non-root, healthcheck, gunicorn
├── .dockerignore
├── docker-compose.yml          # local run
├── Jenkinsfile                 # full CI/CD pipeline
├── terraform/
│   ├── versions.tf             # provider + optional S3 backend
│   ├── variables.tf
│   ├── main.tf                 # AMI lookup, security group, EC2
│   ├── user_data.sh            # installs Docker on boot
│   ├── outputs.tf              # public IP, app URL, ssh command
│   └── terraform.tfvars.example
├── scripts/
│   ├── run_local.sh
│   └── deploy_manual.sh
├── .flake8
├── .gitignore
└── README.md
```

---

## Running it yourself

### 1. Run locally (no Docker)

```bash
git clone https://github.com/<your-username>/flask-devops-pipeline.git
cd flask-devops-pipeline
bash scripts/run_local.sh          # venv + tests + dev server on :5000
```

### 2. Run with Docker

```bash
docker build -t flask-devops-pipeline:local --build-arg APP_VERSION=local .
docker run -d -p 5000:5000 --name flask-app flask-devops-pipeline:local
curl http://localhost:5000/health
# or, equivalently:
docker compose up --build
```

### 3. Provision infrastructure with Terraform

Prerequisites: an AWS account, AWS CLI configured (`aws configure`), Terraform ≥ 1.5,
and an existing EC2 key pair in your chosen region.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set key_name, and ssh_allowed_cidr to YOUR_IP/32

terraform init
terraform validate
terraform plan
terraform apply          # ~1 minute
terraform output app_url
```

Tear everything down when you're done, so you don't get billed for an idle instance:

```bash
terraform destroy
```

### 4. Deploy the container to EC2 manually

This is exactly what the Jenkins "Deploy to EC2" stage automates:

```bash
./scripts/deploy_manual.sh <ec2-public-ip> ~/keys/my-ec2-keypair.pem \
    <dockerhub-user>/flask-devops-pipeline:latest
```

Then open `http://<ec2-public-ip>`.

### 5. Set up the Jenkins pipeline

**Install on the Jenkins host:** Docker, Terraform, Python 3, `git`, `curl`.
Add the Jenkins user to the docker group:
```bash
sudo usermod -aG docker jenkins && sudo systemctl restart jenkins
```

**Plugins:** Git, Pipeline, Docker Pipeline, Credentials Binding, SSH Agent, JUnit.

**Credentials** (Manage Jenkins → Credentials) — IDs must match the `Jenkinsfile`:

| ID | Kind | Value |
|---|---|---|
| `dockerhub-creds` | Username with password | Docker Hub username + access token |
| `aws-access-key-id` | Secret text | AWS access key ID |
| `aws-secret-access-key` | Secret text | AWS secret access key |
| `ec2-ssh-key` | SSH username with private key | username `ubuntu`, contents of your `.pem` |

**Create the job:** New Item → Pipeline → *Pipeline script from SCM* → Git → your repo URL
→ Script Path `Jenkinsfile`. Enable *GitHub hook trigger for GITScm polling* and add a
GitHub webhook pointing to `http://<jenkins-host>:8080/github-webhook/`.

**Before the first run**, edit one line in the `Jenkinsfile`:
```groovy
DOCKERHUB_USER = 'your-dockerhub-username'
```

---

## Design choices worth mentioning

- **Immutable, numbered image tags** (`:BUILD_NUMBER`) — any past build can be redeployed exactly.
- **Non-root container** with a Docker `HEALTHCHECK`, rather than running as root with no self-check.
- **No secrets in the repo** — credentials live in Jenkins; `*.pem`, `terraform.tfvars`, and
  `*.tfstate` are all git-ignored.
- **Dynamic AMI lookup** in Terraform instead of a hard-coded, eventually-stale AMI ID.
- **Idempotent infrastructure** — re-running the pipeline updates the app without recreating the server.
- **Fail-fast ordering** — tests run before the image is even built; the image is smoke-tested
  before it's pushed; the deployment is verified before the pipeline reports success.

## Possible extensions

- Push images to Amazon ECR instead of Docker Hub.
- Replace the SSH deploy with ECS/EKS or an Auto Scaling Group behind a Load Balancer.
- Add Nginx as a reverse proxy with HTTPS via Let's Encrypt.
- Add Prometheus + Grafana for monitoring, or Ansible for configuration management.
- Move Terraform state to the S3 backend already stubbed in `versions.tf`.

## License

MIT
