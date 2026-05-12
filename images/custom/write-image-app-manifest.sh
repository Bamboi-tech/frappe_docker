#!/usr/bin/env bash
set -euo pipefail
APPS_JSON="${1:-}"
BENCH="${2:?bench path required}"
FRAPPE_BRANCH="${3:-version-16}"
FRAPPE_PATH="${4:-https://github.com/frappe/frappe}"
normalize_url() {
	local u="$1"
	u=$(printf '%s' "$u" | sed -E 's|^https?://[^@]+@github\.com/|https://github.com/|')
	u=$(printf '%s' "$u" | sed 's|\.git$||')
	printf '%s\n' "$u" | tr '[:upper:]' '[:lower:]'
}
find_app_for_url() {
	local want remote d
	want=$(normalize_url "$1")
	for d in "${BENCH}/apps"/*; do
		[ -d "$d" ] || continue
		remote=$(git -C "$d" remote get-url origin 2>/dev/null || true)
		[ -z "$remote" ] && continue
		if [ "$(normalize_url "$remote")" = "$want" ]; then
			basename "$d"
			return 0
		fi
	done
	return 1
}
# Under config/ so the file survives Docker's sites/ volume mount (sites/ is replaced at runtime).
OUT="${BENCH}/config/image_app_manifest.json"
mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
echo '[]' >"$TMP"
add_row() {
	local app="$1" url="$2" branch="$3" commit="$4"
	local obj
	obj=$(jq -n \
		--arg app "$app" \
		--arg url "$url" \
		--arg branch "$branch" \
		--arg commit "$commit" \
		'{app: $app, url: $url, branch: $branch, commit: $commit}')
	jq --argjson obj "$obj" '. + [$obj]' "$TMP" >"${TMP}.new" && mv "${TMP}.new" "$TMP"
}
if [ -d "${BENCH}/apps/frappe" ]; then
	fc=$(git -C "${BENCH}/apps/frappe" rev-parse HEAD)
	add_row "frappe" "$(normalize_url "$FRAPPE_PATH")" "$FRAPPE_BRANCH" "$fc"
fi
if [ -n "${APPS_JSON}" ] && [ -f "${APPS_JSON}" ]; then
	norm_fp=$(normalize_url "$FRAPPE_PATH")
	while IFS= read -r row; do
		[ -z "${row:-}" ] && continue
		url=$(printf '%s\n' "$row" | jq -r '.url')
		branch=$(printf '%s\n' "$row" | jq -r '.branch // empty')
		nu=$(normalize_url "$url")
		if [ "$nu" = "$norm_fp" ]; then
			continue
		fi
		app=$(find_app_for_url "$url") || continue
		commit=$(git -C "${BENCH}/apps/${app}" rev-parse HEAD)
		add_row "$app" "$nu" "${branch:-$FRAPPE_BRANCH}" "$commit"
	done < <(jq -c '.[]' "${APPS_JSON}")
fi
jq . "$TMP" >"$OUT"
trap - EXIT
rm -f "$TMP"
