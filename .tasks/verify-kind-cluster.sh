#!/usr/bin/env bash
set -euo pipefail

kubeconfig="${1:?kubeconfig path is required}"
cluster_name="${2:-allotment}"
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -s "$kubeconfig" ] || die "Local kubeconfig not found. Recover it explicitly with: kind export kubeconfig --name ${cluster_name} --kubeconfig ${kubeconfig}"

candidate_kubeconfig="$(mktemp)"
trap 'rm -f "$candidate_kubeconfig"' EXIT
kind export kubeconfig --name "$cluster_name" --kubeconfig "$candidate_kubeconfig" >/dev/null

local_uid="$(kubectl --kubeconfig "$kubeconfig" get namespace kube-system \
  -o jsonpath='{.metadata.uid}' 2>/dev/null)" \
  || die "Local kubeconfig cannot reach its cluster."
kind_uid="$(kubectl --kubeconfig "$candidate_kubeconfig" get namespace kube-system \
  -o jsonpath='{.metadata.uid}' 2>/dev/null)" \
  || die "kind cluster ${cluster_name} is not reachable."

[ -n "$local_uid" ] && [ "$local_uid" = "$kind_uid" ] \
  || die "Local kubeconfig does not belong to kind cluster ${cluster_name}."
install -m 600 "$candidate_kubeconfig" "$kubeconfig"
