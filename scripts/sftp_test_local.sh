#!/usr/bin/env bash
set -euo pipefail

PROJECT=${1:-frappe-local}
COMPOSE_FILE=${2:-$HOME/frappe-local/gitops/docker-compose.yml}
OVERRIDE=${3:-$PWD/overrides/compose.sftp.local.yaml}
SAMPLE=${4:-$HOME/frappe-local/FW_Koppeling_Voorbeelden/Example Inbound 24-08-2022.xml}
KN_HOST=${5:-mft-test.kuehne-nagel.com}
KN_USER=${6:-Bamboi}

cp "$SAMPLE" /tmp/kn_test.xml.tmp || true

docker compose -p "$PROJECT" -f "$COMPOSE_FILE" -f "$OVERRIDE" up -d

# copy sample into backend container /tmp
CID=$(docker compose -p "$PROJECT" -f "$COMPOSE_FILE" ps -q backend)
docker cp /tmp/kn_test.xml.tmp "$CID":/tmp/kn_test.xml.tmp

docker compose -p "$PROJECT" -f "$COMPOSE_FILE" exec backend bash -lc '
  set -e
  cd /home/frappe/frappe-bench
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
    # write explicitly to avoid confirm/size mismatch
    with open("/tmp/kn_test.xml.tmp", "rb") as lf, s.file("kn_local_test.xml.tmp", mode="wb") as rf:
        rf.write(lf.read())
    for f in s.listdir_attr("."):
        print(f.filename)
    s.close()
    t.close()
    print("Uploaded kn_local_test.xml.tmp")
except Exception as e:
    import sys; print("Upload failed:", e); sys.exit(1)
PY
'

echo "Uploaded /tmp/kn_test.xml.tmp to pub/inbound via backend"


