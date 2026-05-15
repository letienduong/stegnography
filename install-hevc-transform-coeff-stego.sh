#!/usr/bin/env bash
set -euo pipefail

LAB_NAME="hevc-transform-coeff-stego"
IMODULE_URL="https://github.com/letienduong/stegnography/raw/refs/heads/main/${LAB_NAME}.tar"
LABTAINER_DIR="${LABTAINER_DIR:-$HOME/labtainer/trunk}"
IMODULE_LIST="$HOME/.local/share/labtainers/imodules.txt"

if [ ! -d "$LABTAINER_DIR/labs" ]; then
    echo "ERROR: LABTAINER_DIR is not valid: $LABTAINER_DIR" >&2
    echo "Set LABTAINER_DIR or run this script inside the Labtainer VM." >&2
    exit 1
fi

echo "[1/4] Installing ${LAB_NAME} IModule"
mkdir -p "$(dirname "$IMODULE_LIST")"
grep -qxF "$IMODULE_URL" "$IMODULE_LIST" 2>/dev/null || echo "$IMODULE_URL" >> "$IMODULE_LIST"
curl -L -s -o "/tmp/${LAB_NAME}.tar" "$IMODULE_URL"
tar -xf "/tmp/${LAB_NAME}.tar" -C "$LABTAINER_DIR/labs"
chmod +x "$LABTAINER_DIR/labs/$LAB_NAME/instr_config/pregrade.sh" 2>/dev/null || true

echo "[2/4] Checking Labtainer grader image"
if ! docker image inspect labtainers/labtainer.grader:latest >/dev/null 2>&1; then
    docker pull labtainers/labtainer.grader:latest
fi

if docker run --rm --entrypoint /bin/sh labtainers/labtainer.grader:latest -lc \
    "grep -q '^instructor:' /etc/passwd && grep -q '^instructor:' /etc/group && [ -d /home/instructor ]" >/dev/null 2>&1; then
    echo "grader image already has instructor user"
else
    echo "[3/4] Patching labtainers/labtainer.grader locally"
    PATCH_DIR="/tmp/${LAB_NAME}-grader-patch"
    mkdir -p "$PATCH_DIR"
    cat > "$PATCH_DIR/Dockerfile" <<'EOF'
FROM labtainers/labtainer.grader:latest
RUN id instructor >/dev/null 2>&1 || useradd -ms /bin/bash instructor
RUN mkdir -p /home/instructor && chown -R instructor:instructor /home/instructor
EOF
    docker build -q -t labtainers/labtainer.grader:latest "$PATCH_DIR" >/dev/null
fi

echo "[4/4] Removing stale grader container"
docker rm -f "${LAB_NAME}-igrader" >/dev/null 2>&1 || true

echo "Done. Start the lab with:"
echo "  labtainer -r ${LAB_NAME}"
