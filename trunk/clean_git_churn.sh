#!/bin/sh
# Restore build-time autotools and generated board-header churn in git
# without deleting trunk/images/, trunk/romfs/, trunk/.config, or user source edits.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOPDIR="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$TOPDIR" ] || exit 0

TMP_LIST="$(mktemp /tmp/padavan_churn.XXXXXX)" || exit 1
trap 'rm -f "$TMP_LIST"' EXIT HUP INT TERM

git -C "$TOPDIR" diff --name-only -z HEAD -- \
    "trunk/linux-3.4.x/drivers/mtd/mtdsplitter_parts.h" \
    "trunk/user/shared/board.mk" \
    "trunk/user/shared/include/ralink_board.h" \
    "trunk/libs" \
    "trunk/tools" \
    "trunk/user/util-linux" \
    "trunk/user/rpcbind" \
    "trunk/user/lua" \
    "trunk/user/dosfstools" \
    "trunk/user/iptables" \
    "trunk/user/busybox" \
    "trunk/user/e2fsprogs" \
    "trunk/user/parted" \
    "trunk/user/dropbear" \
    "trunk/user/openssh" \
    "trunk/user/openvpn" \
    "trunk/user/pppd" \
    "trunk/user/xl2tpd" \
    "trunk/user/dnsmasq" \
    "trunk/user/miniupnpd" \
    "trunk/user/samba36" \
    "trunk/user/vsftpd" \
    "trunk/user/wpa_supplicant" \
    "trunk/user/ntfs-3g" \
    "trunk/user/nfs-utils" \
    "trunk/user/inadyn" \
    | tr '\0' '\n' \
    | awk '
        $0 == "trunk/linux-3.4.x/drivers/mtd/mtdsplitter_parts.h" ||
        $0 == "trunk/user/shared/board.mk" ||
        $0 == "trunk/user/shared/include/ralink_board.h" ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/(Makefile\.in|aclocal\.m4|configure|configure~|config\.h\.in|INSTALL|zconf\.h|liblua\.so.*|POTFILES\.in|version\.xml)$/ ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/config\/(compile|depcomp|ltmain\.sh|missing|config\.guess|config\.sub)$/ ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/m4\/.*\.m4$/ ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/docs\/Makefile\.in$/ {
            print
        }
    ' > "$TMP_LIST"

if [ -s "$TMP_LIST" ]; then
    COUNT="$(wc -l < "$TMP_LIST" | tr -d ' ')"
    echo "Restoring $COUNT build-generated/autotools churn file(s) (preserving images/)..."
    tr '\n' '\0' < "$TMP_LIST" | xargs -0 -r git -C "$TOPDIR" restore --worktree -- 2>/dev/null || true
fi

# Keep autotools generated files newer than configure.ac/aclocal.m4 to prevent re-running automake on incremental builds
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" -name "Makefile.in" -exec touch {} + 2>/dev/null || true
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" -name "config.h.in" -exec touch {} + 2>/dev/null || true
