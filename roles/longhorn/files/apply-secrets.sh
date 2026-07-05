#!/usr/bin/env bash
#
# Generate the longhorn-ui-auth Secret (nginx basic-auth htpasswd) from the
# Kauket-managed env file. Replaces the old sealed-secret: the htpasswd now
# lives in the Kauket store (k8s.longhorn_ui_auth_env, profile role.k8s_admin)
# and is installed locally by `kauket get`. Invoked by the longhorn role and
# runnable standalone on a k8s-admin host.
#
# Env: KUBECONFIG (optional), LONGHORN_NAMESPACE (default longhorn-system),
#      K8S_SECRETS_DIR (default ~/k8s-secrets).
#
set -euo pipefail

NS="${LONGHORN_NAMESPACE:-longhorn-system}"
KUBECTL="${KUBECTL:-kubectl}"
[ -n "${KUBECONFIG:-}" ] && KUBECTL="$KUBECTL --kubeconfig=$KUBECONFIG"
ENVF="${K8S_SECRETS_DIR:-$HOME/k8s-secrets}/longhorn-ui-auth.env"

if command -v kauket >/dev/null 2>&1; then
    KAUKET_HOME="${KAUKET_HOME:-$HOME/.config/kauket}" kauket get k8s.longhorn_ui_auth_env >/dev/null 2>&1 || true
fi
[ -s "$ENVF" ] || { echo "apply-secrets: missing $ENVF (run: kauket get k8s.longhorn_ui_auth_env)" >&2; exit 1; }

$KUBECTL create secret generic longhorn-ui-auth -n "$NS" \
    --from-env-file="$ENVF" --dry-run=client -o yaml | $KUBECTL apply -f -
