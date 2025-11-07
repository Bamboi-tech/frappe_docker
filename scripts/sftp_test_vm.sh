#!/usr/bin/env bash
set -euo pipefail

PROJECT=${1:-erpnext-vm-bamboi}
COMPOSE_FILE=${2:-$HOME/gitops/docker-compose.yml}
TMP_OVERRIDE=${3:-/tmp/compose.ssh-mount.yaml}
KN_HOST=${4:-mft-test.kuehne-nagel.com}
KN_USER=${5:-Bamboi}

cat > "$TMP_OVERRIDE" <<'YAML'
services:
  backend:
    volumes:
      - ~/.ssh/kn_mft_test_ed25519:/home/frappe/.ssh/kn_mft_test_ed25519:ro
YAML

docker compose -p "$PROJECT" -f "$COMPOSE_FILE" -f "$TMP_OVERRIDE" up -d

docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend bash -lc '
  set -e
  cd /home/frappe/frappe-bench
  echo "test" > /tmp/kn_probe.xml.tmp
  # ensure paramiko available in bench venv
  env/bin/python -c "import paramiko" || env/bin/pip install -q paramiko
  env/bin/python - <<PY
import paramiko, os
host = os.environ.get("KN_HOST","'"$KN_HOST"'")
user = os.environ.get("KN_USER","'"$KN_USER"'")
key_path = "/home/frappe/.ssh/kn_mft_test_ed25519"
try:
    try:
        pk = paramiko.Ed25519Key.from_private_key_file(key_path)
    except Exception:
        pk = paramiko.RSAKey.from_private_key_file(key_path)
    t = paramiko.Transport((host, 22))
    t.connect(username=user, pkey=pk)
    s = paramiko.SFTPClient.from_transport(t)
    s.chdir("pub/inbound")
    with open("/tmp/kn_probe.xml.tmp", "rb") as lf, s.file("kn_vm_probe.xml.tmp", mode="wb") as rf:
        rf.write(lf.read())
    for f in s.listdir_attr("."):
        print(f.filename)
    s.close()
    t.close()
    print("Uploaded kn_vm_probe.xml.tmp")
except Exception as e:
    import sys; print("Upload failed:", e); sys.exit(1)
PY
'

echo "Uploaded /tmp/kn_probe.xml.tmp to pub/inbound via backend (VM)"


