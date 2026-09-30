#!/usr/bin/env bash
# pmb-journal.sh — per-session journal for concurrent sessions working one repository.
#
# Spec: docs/superpowers/specs/2026-09-26-multi-session-memory-design.md (sections 4.1-4.3).
# Twin: scripts/pmb-journal.ps1 — same commands, same on-disk layout, same limits.
#
# WHY a standalone script rather than an `mb` subcommand: `mb` runs MB_HOME's mb.ps1 (the main
# checkout, on whatever branch it holds), prints an update notice that can make a 2 s network call,
# and pwsh takes ~1.4 s just to load mb.ps1 (spec F18/F19). Hooks and messages call this file by its
# repo-local path instead.
#
# WHY no `set -e`: the gate must fail OPEN on unexpected errors (spec section 4.3), so failure paths
# are handled explicitly and `die` is used only by the non-gate commands.
#
# WHY LC_ALL=C: every limit is in BYTES (the 1,024-byte body, the 900-byte import chunk), and the
# character checks match raw UTF-8 byte sequences. Under C, ${#var} counts bytes and bracket ranges
# compare bytes, the same in every locale the script is started from.
#
# Trust: anything under .git/ can be written by any local process. The name, seq and character
# checks below catch accidents and planted junk; they are not a security boundary (spec S3).
set -u
export LC_ALL=C

PMB_MAX_BODY=1024
PMB_MAX_FILE=65536
PMB_MIN_GATE_BODY=40
PMB_IMPORT_CHUNK=900
PMB_SEQ_MAX=999999
PMB_KINDS=" claim release note handoff pickup learned decision blocked done promoted "
PMB_GATE_KINDS=" done learned decision blocked note handoff "
# NS ids are canonical: NS-5, never NS-05, so two claims on one item always share a name.
PMB_NS_RE='NS-(0|[1-9][0-9]{0,4})'
PMB_NAME_RE="^[0-9]{8}T[0-9]{6}Z-[0-9]{6}-(start|compact|end|claim|release|note|handoff|pickup|learned|decision|blocked|done|promoted)(-$PMB_NS_RE)?-[0-9a-f]{6}\\.md\$"
PMB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PMB_BOM=$'\xef\xbb\xbf'

die() { printf 'pmb-journal: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
usage: pmb-journal.sh <command> [args]
  <kind> [NS-<n>] [--session <id>] (--file <path> | <text>)   record an entry
      kinds: claim release note handoff pickup learned decision blocked done promoted
  start                          print a new session id (for clients without CLAUDE_CODE_SESSION_ID)
  show [--all] (--own | <id>)    print a session's records (the last 100 unless --all)
  import-handoff <path>          convert a legacy handoff.md into journal handoff records
  mode                           exit 0 if this repository has opted in (.pmb-features on origin/main)
  gate                           PreCompact gate (reads the hook payload on stdin)
EOF
}

pmb_toplevel() { git rev-parse --show-toplevel 2>/dev/null; }

# pmb_dir — prints <git-common-dir>/pmb as an absolute path; fails outside a repository.
pmb_dir() {
    local common
    common=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
    [ -n "$common" ] || return 1
    common=$(cd "$common" 2>/dev/null && pwd -P) || return 1
    printf '%s/pmb' "$common"
}

# pmb_flag_on — the repository has opted in. Read ONLY through the remote-tracking ref's SHA:
# a short `origin/main` can be shadowed by a local branch or tag (spec F16), MSYS path conversion
# mangles `origin/main:.dotfile` (F15), and an empty revision reads the index (F17). A leading
# UTF-8 BOM is ignored, as the PowerShell twin's decoder does.
pmb_flag_on() {
    local sha content
    sha=$(git rev-parse --verify -q refs/remotes/origin/main 2>/dev/null) || return 1
    [ -n "$sha" ] || return 1
    content=$(MSYS_NO_PATHCONV=1 git show "$sha:.pmb-features" 2>/dev/null) || return 1
    content="${content#"$PMB_BOM"}"
    printf '%s\n' "$content" | tr -d '\r' | grep -qx 'journal=on'
}

# WHY [[ =~ ]] rather than grep: readers and the gate validate every record name, and a fork per
# name is slow under Git Bash on Windows, where the gate runs as a hook.
pmb_valid_sid()  { [[ $1 =~ ^[A-Za-z0-9_-]{8,64}$ ]]; }
pmb_valid_ns()   { [[ $1 =~ ^$PMB_NS_RE$ ]]; }
pmb_valid_name() { [[ $1 =~ $PMB_NAME_RE ]]; }

# pmb_text_ok TEXT — the character set every stored body keeps (spec section 4.2). Refused: ASCII
# controls other than TAB and LF, C1 controls, and the invisible characters used to hide
# instructions from a human reader -- zero-width and bidi controls (including U+061C), word joiners,
# a BOM after the first byte, the Unicode tag block and the variation selectors supplement
# (U+E0100-E01EF). U+FE00-FE0F stay allowed (emoji presentation). A denylist, not a proof. Matched as UTF-8 byte sequences (LC_ALL=C above).
pmb_text_ok() {
    local t="$1"
    [[ $t == *[$'\x01'-$'\x08'$'\x0b'-$'\x1f'$'\x7f']* ]] && return 1
    [[ $t == *$'\xc2'[$'\x80'-$'\x9f']* ]] && return 1                     # C1 controls
    [[ $t == *$'\xe2\x80'[$'\x8b'-$'\x8f'$'\xa8'-$'\xae']* ]] && return 1  # ZW*, LRM/RLM, LS/PS, bidi
    [[ $t == *$'\xe2\x81'[$'\xa0'-$'\xaf']* ]] && return 1                 # word joiner, invisible ops
    [[ $t == *$'\xef\xbb\xbf'* ]] && return 1                              # BOM / ZWNBSP
    [[ $t == *$'\xd8\x9c'* ]] && return 1                                  # U+061C Arabic letter mark
    [[ $t == *$'\xf3\xa0'[$'\x80'$'\x81']* ]] && return 1                  # tag characters
    [[ $t == *$'\xf3\xa0'[$'\x84'-$'\x87']* ]] && return 1                 # variation selectors supplement
    return 0
}

# pmb_sid EXPLICIT — the session id: CLAUDE_CODE_SESSION_ID wins; an explicit --session must match
# it when both exist (spec section 4.2). Prints the id; exits via die on any problem.
pmb_sid() {
    local explicit="$1" env="${CLAUDE_CODE_SESSION_ID:-}"
    if [ -n "$env" ]; then
        [ -z "$explicit" ] || [ "$explicit" = "$env" ] || die "--session differs from CLAUDE_CODE_SESSION_ID"
        explicit="$env"
    fi
    [ -n "$explicit" ] || die "no session id: set CLAUDE_CODE_SESSION_ID or pass --session (get one with: pmb-journal.sh start)"
    pmb_valid_sid "$explicit" || die "invalid session id (want [A-Za-z0-9_-]{8,64})"
    printf '%s' "$explicit"
}

# pmb_normalize — stdin to stdout: drop CR and the ASCII controls other than TAB and LF.
pmb_normalize() { tr -d '\r' | tr -d '\000-\010\013\014\016-\037\177'; }

# pmb_check_body BODY — prints the refusal reason and returns 1 if BODY may not be stored.
pmb_check_body() {
    local body="$1" patterns="$PMB_SCRIPT_DIR/secret-patterns.txt" list rc
    [ -n "${body//[[:space:]]/}" ] || { echo "empty body"; return 1; }
    [ "${#body}" -le "$PMB_MAX_BODY" ] || { echo "body is ${#body} bytes (max $PMB_MAX_BODY)"; return 1; }
    printf '%s' "$body" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 || { echo "body is not valid UTF-8"; return 1; }
    pmb_text_ok "$body" || { echo "body contains a control or invisible character"; return 1; }
    # WHY trailing whitespace counts: `--- ` still opens frontmatter in common parsers.
    if printf '%s\n' "$body" | grep -qxE -- '---[[:space:]]*'; then echo "body contains a '---' line"; return 1; fi
    # WHY fail closed on a missing, empty or invalid list: the writer is not the gate, so refusing
    # costs a retry at most, while failing open could store a secret in plain text under .git/.
    [ -f "$patterns" ] || { echo "scripts/secret-patterns.txt is missing"; return 1; }
    list=$(grep -vE '^(#|$)' "$patterns")
    [ -n "$list" ] || { echo "scripts/secret-patterns.txt has no patterns"; return 1; }
    printf '%s\n' "$body" | grep -qiE -f <(printf '%s\n' "$list") 2>/dev/null; rc=$?
    case "$rc" in
        0) echo "body matches a secret pattern"; return 1 ;;
        1) return 0 ;;
        *) echo "scripts/secret-patterns.txt could not be applied (grep exit $rc)"; return 1 ;;
    esac
}

pmb_rand6() { od -An -N3 -tx1 /dev/urandom | tr -d ' \n'; }
# WHY the test seams are validated in the shipped writer: they are read from the environment, and
# an unchecked PMB_TEST_TS becomes a path component of the published name (`../` would place a link
# to the record outside r/). A value that is not the documented shape is ignored.
pmb_now()   { if [[ ${PMB_TEST_TS:-} =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then printf '%s' "$PMB_TEST_TS"; else date -u +%Y%m%dT%H%M%SZ; fi; }

# pmb_max_seq SDIR — the highest sequence number the session has allocated, from seq/ AND from the
# record names in r/. WHY both: if seq/ is lost, counting from r/ keeps new records above the last
# compact marker, so the gate can still pass (review finding: seq restarted at 1).
pmb_max_seq() {
    local p n max=0
    for p in "$1"/seq/* "$1"/r/*; do
        n="${p##*/}"
        if [[ $n =~ ^[0-9]{1,6}$ ]]; then :
        elif pmb_valid_name "$n"; then n="${n#*-}"; n="${n%%-*}"
        else continue; fi
        n=$((10#$n)); [ "$n" -gt "$max" ] && max=$n
    done
    printf '%d' "$max"
}

# pmb_next_seq SDIR — allocate the next sequence number. WHY an exclusive CREATE (noclobber uses
# O_EXCL): two writers in one session can never both obtain the same number. A failed create is a
# collision only if the file now exists; any other failure (missing or unwritable seq/, full disk)
# returns at once instead of retrying up to the cap.
pmb_next_seq() {
    local d="$1/seq" n
    n=""; [[ ${PMB_TEST_SEQ_START:-} =~ ^[0-9]{1,6}$ ]] && n=$((10#$PMB_TEST_SEQ_START))
    [ -n "$n" ] || n=$(( $(pmb_max_seq "$1") + 1 ))
    while [ "$n" -le "$PMB_SEQ_MAX" ]; do
        if ( set -o noclobber; : > "$d/$n" ) 2>/dev/null; then printf '%06d' "$n"; return 0; fi
        [ -e "$d/$n" ] || return 1
        n=$((n + 1))
    done
    return 1
}

# pmb_publish SDIR KIND NS BODY — write the record to tmp/, then link it into r/ under a unique
# name. WHY ln, not mv: mv silently replaces an existing file, while ln refuses — so a collision
# can never overwrite another record (spec section 4.2). Prints the published path.
pmb_publish() {
    local sdir="$1" kind="$2" ns="$3" body="$4" dir seq name tmp final rand tries=0
    dir="${sdir%/sessions/*}"
    seq=$(pmb_next_seq "$sdir") || die "cannot allocate a sequence number in $sdir/seq"
    name="$(pmb_now)-$seq-$kind${ns:+-$ns}"
    tmp=$(mktemp "$dir/tmp/rec.XXXXXX") || die "cannot create a temp file in $dir/tmp"
    printf '%s\n' "$body" > "$tmp" || { rm -f "$tmp"; die "cannot write $tmp"; }
    rand=""; [[ ${PMB_TEST_RAND:-} =~ ^[0-9a-f]{6}$ ]] && rand="$PMB_TEST_RAND"
    while [ "$tries" -lt 20 ]; do
        [ -n "$rand" ] || rand=$(pmb_rand6)
        final="$sdir/r/$name-$rand.md"
        if ln "$tmp" "$final" 2>/dev/null; then
            rm -f "$tmp"
            # WHY the -L check: touch follows a symbolic link, so a planted one would move the
            # mtime of (or create) a file outside the journal.
            [ -L "$sdir/heartbeat" ] && rm -f "$sdir/heartbeat"
            touch "$sdir/heartbeat"
            printf '%s\n' "$final"
            return 0
        fi
        rand=""
        tries=$((tries + 1))
    done
    rm -f "$tmp"
    die "could not publish a record after 20 attempts"
}

# pmb_ensure_session SID — create the session directory and meta file if needed; print its path.
# WHY refuse symbolic links: mkdir -p and every later write follow them, which would move the
# session's files outside .git/pmb.
pmb_ensure_session() {
    local sid="$1" dir sdir tmp p
    dir=$(pmb_dir) || die "not inside a git repository"
    if [ -e "$dir" ] && [ ! -d "$dir" ]; then die "$dir exists but is not a directory"; fi
    sdir="$dir/sessions/$sid"
    for p in "$dir" "$dir/sessions" "$sdir" "$sdir/r" "$sdir/seq" "$dir/tmp"; do
        [ ! -L "$p" ] || die "$p is a symbolic link; refusing to write through it"
    done
    mkdir -p "$sdir/r" "$sdir/seq" "$dir/tmp" || die "cannot create $sdir"
    if [ ! -f "$sdir/meta" ]; then
        tmp=$(mktemp "$dir/tmp/meta.XXXXXX") || die "cannot create a temp file in $dir/tmp"
        {
            printf 'worktree=%s\n' "$(pmb_toplevel)"
            printf 'branch=%s\n' "$(git branch --show-current 2>/dev/null | tr -cd 'A-Za-z0-9._/-' | cut -c1-60)"
            printf 'started=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        } > "$tmp"
        mv -f "$tmp" "$sdir/meta"
    fi
    printf '%s' "$sdir"
}

# pmb_write_cmd KIND ARGS... — parse and store one record.
pmb_write_cmd() {
    local kind="$1"; shift
    local ns="" file="" session="" text="" sid sdir body reason rec
    while [ $# -gt 0 ]; do
        case "$1" in
            --session) [ $# -ge 2 ] || die "--session needs a value"; session="$2"; shift 2 ;;
            --file)    [ $# -ge 2 ] || die "--file needs a path"; file="$2"; shift 2 ;;
            *)
                if [ -z "$ns" ] && [ -z "$text" ] && pmb_valid_ns "$1"; then ns="$1"
                else text="${text:+$text }$1"; fi
                shift ;;
        esac
    done
    [ -z "$file" ] || [ -z "$text" ] || die "give --file or text, not both"
    case "$kind" in
        claim|release)
            [ -n "$ns" ] || die "$kind needs a canonical NS id (NS-<digits>, no leading zeros)"
            [ -n "$file" ] || [ -n "$text" ] || text="$kind $ns" ;;
        pickup)
            pmb_valid_sid "$text" || die "pickup needs the source session id"
            text="picked up handoff from session $text" ;;
    esac
    sid=$(pmb_sid "$session") || exit 1
    if [ -n "$file" ]; then
        # WHY these checks before the read: the file is read whole into a shell variable and a link
        # would copy the first bytes of any readable file into the journal. A bounded size keeps a huge
        # file from exhausting the writer; the body limit is still applied afterwards.
        { [ -f "$file" ] && [ ! -L "$file" ]; } || die "not a regular file (or a link): $file"
        [ "$(wc -c < "$file")" -le "$PMB_MAX_FILE" ] || die "file is larger than $PMB_MAX_FILE bytes: $file"
        body=$(pmb_normalize < "$file")
    else
        body=$(printf '%s' "$text" | pmb_normalize)
    fi
    body="${body#"$PMB_BOM"}"
    reason=$(pmb_check_body "$body") || die "refused: $reason"
    sdir=$(pmb_ensure_session "$sid") || exit 1
    # WHY an exclusive sentinel: two first writes at once would otherwise both see an empty r/ and
    # both publish a start marker, and a later duplicate start hides the earlier write from the gate.
    if ( set -o noclobber; : > "$sdir/started" ) 2>/dev/null; then
        pmb_publish "$sdir" start "" "session start" >/dev/null || exit 1
    fi
    rec=$(pmb_publish "$sdir" "$kind" "$ns" "$body") || exit 1
    printf 'recorded %s in session %s\n' "${rec##*/}" "$sid"
    return 0
}

cmd="${1:-help}"
[ $# -gt 0 ] && shift
case "$cmd" in
    mode)  pmb_flag_on; exit $? ;;
    start) od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; echo; exit 0 ;;
    help|-h|--help) usage; exit 0 ;;
    *)
        case "$PMB_KINDS" in
            *" $cmd "*) pmb_write_cmd "$cmd" "$@"; exit $? ;;
            *) usage >&2; exit 1 ;;
        esac ;;
esac
