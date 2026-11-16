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
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/(ar-lib|compile|config\.guess|config\.sub|depcomp|install-sh|ltmain\.sh|mdate-sh|missing|py-compile|test-driver|texinfo\.tex)$/ ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/m4\/.*\.m4$/ ||
        $0 ~ /^trunk\/(libs|tools|user)\/.*\/docs\/Makefile\.in$/ ||
        $0 ~ /^trunk\/libs\/libconfuse\/.*\/(doc\/Doxyfile|libconfuse\.spec)$/ ||
        $0 ~ /^trunk\/libs\/libcurl\/.*\/lib\/curl_config\.h\.in$/ ||
        $0 ~ /^trunk\/libs\/libnetfilter_queue\/.*\/include\/linux\/(netfilter\/)?Makefile$/ ||
        $0 ~ /^trunk\/libs\/libnl\/.*\/(include\/netlink\/version\.h|lib\/defs\.h\.in~?)$/ {
            print
        }
    ' > "$TMP_LIST"

if [ -s "$TMP_LIST" ]; then
    COUNT="$(wc -l < "$TMP_LIST" | tr -d ' ')"
    echo "Restoring $COUNT build-generated/autotools churn file(s) (preserving images/)..."
    tr '\n' '\0' < "$TMP_LIST" | xargs -0 -r git -C "$TOPDIR" restore --worktree -- 2>/dev/null || true
fi

# Keep autotools timestamps strictly ordered across 4 tiers:
# Tier 1: aclocal.m4 strictly newer than restored configure.ac / m4/*.m4
sleep 1
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" \
    -name "aclocal.m4" -exec touch {} + 2>/dev/null || true

# Tier 2: Templates/scripts strictly newer than aclocal.m4 / Makefile.am / configure.ac
sleep 1
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" \
    \( -name "configure" -o -name "Makefile.in" -o -name "config.h.in" -o -name "defs.h.in" -o -name "curl_config.h.in" -o -name "POTFILES.in" \) \
    -exec touch {} + 2>/dev/null || true

# Tier 3: Configure state markers strictly newer than Tier 2 so config.status --recheck does not trigger
sleep 1
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" \
    \( -name "config.status" -o -name "config_done" \) \
    -exec touch {} + 2>/dev/null || true

# Tier 4: Already-configured generated outputs strictly newer than Tier 1..3
# so incremental builds neither regenerate Makefiles from restored templates nor recompile parted/e2fsprogs
sleep 1
find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" \
    -name "stamp-h*" -exec touch {} + 2>/dev/null || true

find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" -name "Makefile.in" 2>/dev/null \
    | while IFS= read -r mf_in; do
        mf_dir="$(dirname "$mf_in")"
        [ -f "$mf_dir/Makefile" ] && touch "$mf_dir/Makefile"
    done

find "$SCRIPT_DIR/libs" "$SCRIPT_DIR/user" "$SCRIPT_DIR/tools" \
    \( -name "config.h.in" -o -name "defs.h.in" -o -name "curl_config.h.in" -o -name "POTFILES.in" -o -name "MCONFIG.in" \) 2>/dev/null \
    | while IFS= read -r ch_in; do
        ch_dir="$(dirname "$ch_in")"
        case "$(basename "$ch_in")" in
            config.h.in) [ -f "$ch_dir/config.h" ] && touch "$ch_dir/config.h" ;;
            defs.h.in) [ -f "$ch_dir/defs.h" ] && touch "$ch_dir/defs.h" ;;
            curl_config.h.in) [ -f "$ch_dir/curl_config.h" ] && touch "$ch_dir/curl_config.h" ;;
            POTFILES.in) [ -f "$ch_dir/POTFILES" ] && touch "$ch_dir/POTFILES" ;;
            MCONFIG.in) [ -f "$ch_dir/MCONFIG" ] && touch "$ch_dir/MCONFIG" ;;
        esac
    done
