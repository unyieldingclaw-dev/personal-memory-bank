#!/usr/bin/env bash
# tests/test-review-gate-tag-push.sh — the push gate's tag-only route, both twins
#
# WHY this file exists: the push gate hashed `git diff origin/main...HEAD` for every push, so
# `git push origin v1.3.0` (2026-10-25, right after release 1.3.0 merged) was denied unless a
# fresh /change-review re-reviewed whatever branch happened to be checked out -- a diff that has
# nothing to do with what a tag push publishes. From a checkout of main it could not pass at all:
# that diff is empty, and the empty-diff deny fired.
#
# A tag push now needs no marker when two things hold:
#   * The whole command is `cd "<absolute path>" && git push <remote> refs/tags/<t>` (or `tag <t>`).
#   * Every tag is on a commit already in refs/remotes/origin/main.
#
# Each `expect` row runs against both review-reminders.sh and .ps1 when pwsh is installed. A few
# rows are for one twin and say so. The deny rows pin that the branch-push forms listed below, and
# the tag pushes outside that shape, still need the marker.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== review gate: tag-only pushes ==="

if ! command -v python3 >/dev/null 2>&1; then
  # The bash twin classifies through python3; without it every push is a fallback verdict.
  echo "  SKIP: python3 is not installed, so the bash twin cannot classify a tag push"
  [ "${PMB_REQUIRE_PARITY:-0}" = "1" ] && assert_contains "python3-missing" "python3-present" "PMB_REQUIRE_PARITY=1 but python3 is not on PATH"
  print_summary
  exit $?
fi

TMP_TP="$(mktemp -d 2>/dev/null || mktemp -d -t mb-tag-push)"
trap 'rm -rf "$TMP_TP"' EXIT

# C:/... on Windows: both twins accept it, where /c/... is bash-only.
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

W="$TMP_TP/w"
git init -q --bare "$TMP_TP/origin.git"
git init -q -b main "$W"
git -C "$W" config user.email "test@example.com"
git -C "$W" config user.name "Test"
echo "merged" > "$W/file.txt"
git -C "$W" add file.txt
git -C "$W" commit -q -m "merged"
git -C "$W" remote add origin "$TMP_TP/origin.git"
git -C "$W" push -q origin main 2>/dev/null
git -C "$W" fetch -q origin
git -C "$W" tag -a v1 -m "annotated, on main"
git -C "$W" tag lw1
git -C "$W" tag -a v1-of-v1 -m "a tag of a tag" v1
git -C "$W" checkout -q -b feature
echo "unreviewed" >> "$W/file.txt"
git -C "$W" commit -q -am "unreviewed"
git -C "$W" tag vbad
git -C "$W" tag -a vbad-ann -m "annotated, off main"
git -C "$W" tag treetag "HEAD^{tree}"
git -C "$W" checkout -q main
mkdir -p "$W/.claude"

echo ""
echo "--- fixture checks ---"
git -C "$W" merge-base --is-ancestor v1 refs/remotes/origin/main
assert_exit_zero "$?" "v1 is on refs/remotes/origin/main (fixture check)"
git -C "$W" merge-base --is-ancestor vbad refs/remotes/origin/main
assert_exit_nonzero "$?" "vbad is not on refs/remotes/origin/main (fixture check)"
git -C "$W" rev-parse --verify --quiet "refs/tags/treetag^{commit}" >/dev/null
assert_exit_nonzero "$?" "treetag does not peel to a commit (fixture check)"

# JSON-encode the command. A raw control character would be invalid JSON, which the bash twin's
# python3 rejects and pwsh accepts.
#
# json.dumps writes non-ASCII as \uXXXX escapes, so the typographic-quote rows below reach both
# twins intact whatever encoding each reads stdin with. MSYS_NO_PATHCONV stops Git Bash rewriting
# a path-shaped argument on its way to the native python.
payload() {
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' python3 -I -c \
    'import json, sys; sys.stdout.write(json.dumps({"tool_input": {"command": sys.argv[1]}}))' "$1"
}

run_hook() {
  # run_hook sh|ps1 <command>
  if [ "$1" = sh ]; then
    payload "$2" | (cd "$W" && bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null)
  else
    payload "$2" | (cd "$W" && pwsh -NonInteractive -File "$REPO_ROOT/scripts/review-reminders.ps1" 2>/dev/null)
  fi
}

reason_of() {
  python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])' 2>/dev/null
}

TWINS="sh"
if command -v pwsh >/dev/null 2>&1; then TWINS="sh ps1"; fi

# expect allow|deny <description> <command> [<substring of the decoded deny reason>]
# NEEDLE_SKIP_TWIN names a twin whose deny is checked without the needle. See its one use below.
NEEDLE_SKIP_TWIN=""
expect() {
  local want="$1" desc="$2" command="$3" needle="${4:-}" twin out
  for twin in $TWINS; do
    out=$(run_hook "$twin" "$command")
    if [ "$want" = allow ]; then
      # Empty output is the allow. A crashed hook prints nothing too, so the allow rows share a
      # fixture with deny rows that do print, most of them differing from an allow row in one thing.
      assert_equals "$out" "" "[$twin] allows: $desc"
    else
      assert_contains "$out" '"permissionDecision":"deny"' "[$twin] denies: $desc"
      if [ -n "$needle" ] && [ "$twin" != "$NEEDLE_SKIP_TWIN" ]; then
        reason=$(printf '%s' "$out" | reason_of)
        assert_contains "$reason" "$needle" "[$twin] deny reason for '$desc' says: $needle"
        # Print the reason a needle missed, so an intermittent failure can be diagnosed from the log.
        case "$reason" in *"$needle"*) ;; *) echo "    actual reason: $(printf '%s' "$reason" | cut -c1-240)" ;; esac
      fi
    fi
  done
}

TAG_REASON="A tag push needs no review marker only when"
TAG_HINT="git push <remote> refs/tags/<tag>"
TAB=$(printf '\t')
# The one cd the tag route requires: quoted, absolute, first. The rows that test a tag push carry
# it, so each differs from an allow row only in the thing it tests.
CDW="cd \"$(native "$W")\" && "

echo ""
echo "--- allowed: tags on commits already in origin/main ---"
printf 'sentinel' > "$W/.claude/.change-review-ok"
expect allow "annotated tag by full ref" "${CDW}git push origin refs/tags/v1"
expect allow "lightweight tag by the tag keyword" "${CDW}git push origin tag lw1"
expect allow "two tags, both forms" "${CDW}git push origin refs/tags/v1 tag lw1"
expect allow "a tag of a tag" "${CDW}git push origin refs/tags/v1-of-v1"
expect allow "tab-separated words" "${CDW}git push${TAB}origin${TAB}refs/tags/v1"
expect allow "a single-quoted cd" "cd '$(native "$W")' && git push origin refs/tags/v1"
expect allow "no space before &&" "cd \"$(native "$W")\"&& git push origin refs/tags/v1"
assert_equals "$(cat "$W/.claude/.change-review-ok" 2>/dev/null)" "sentinel" "an allowed tag push leaves the change-review marker untouched"
rm -f "$W/.claude/.change-review-ok"

echo ""
echo "--- denied: the tag is not on a merged commit ---"
expect deny "lightweight tag off main" "${CDW}git push origin refs/tags/vbad" "$TAG_REASON"
expect deny "annotated tag off main" "${CDW}git push origin tag vbad-ann" "$TAG_REASON"
expect deny "tag of a tree" "${CDW}git push origin refs/tags/treetag" "$TAG_REASON"
expect deny "tag that does not exist" "${CDW}git push origin refs/tags/nosuch" "$TAG_REASON"
expect deny "one good tag and one bad" "${CDW}git push origin refs/tags/v1 refs/tags/vbad" "$TAG_REASON"
expect deny "one bad tag and one good" "${CDW}git push origin refs/tags/vbad refs/tags/v1" "$TAG_REASON"

echo ""
echo "--- denied: not the tag-only shape, so the marker is required as before ---"
expect deny "no cd (the tag route requires one)" "git push origin refs/tags/v1" "$TAG_HINT"
expect deny "; instead of &&" "cd \"$(native "$W")\"; git push origin refs/tags/v1" "$TAG_HINT"
expect deny "|| instead of &&" "cd \"$(native "$W")\" || git push origin refs/tags/v1" "$TAG_HINT"
expect deny "bare tag name (hint names the accepted form)" "${CDW}git push origin v1" "$TAG_HINT"
expect deny "tag plus a branch" "${CDW}git push origin refs/tags/v1 main"
expect deny "branch plus a tag" "${CDW}git push origin main refs/tags/v1"
expect deny "--tags" "${CDW}git push origin --tags"
expect deny "--tags before the remote" "${CDW}git push --tags origin"
expect deny "--follow-tags" "${CDW}git push --follow-tags origin main"
expect deny "--mirror" "${CDW}git push --mirror origin"
expect deny "--all" "${CDW}git push --all origin"
expect deny "-f" "${CDW}git push -f origin refs/tags/v1"
expect deny "--force" "${CDW}git push --force origin refs/tags/v1"
expect deny "+ force refspec" "${CDW}git push origin +refs/tags/v1"
expect deny "delete by empty source" "${CDW}git push origin :refs/tags/v1"
expect deny "--delete" "${CDW}git push origin --delete refs/tags/v1"
expect deny "-d" "${CDW}git push -d origin refs/tags/v1"
# An option in the remote's place, with valid tag words after it: only the remote's
# first-character rule stops these (git would take the next word as the remote, and the option
# would apply).
expect deny "-f in the remote's place" "${CDW}git push -f tag v1" "$TAG_HINT"
expect deny "--force in the remote's place" "${CDW}git push --force refs/tags/v1" "$TAG_HINT"
expect deny "--follow-tags in the remote's place" "${CDW}git push --follow-tags tag v1" "$TAG_HINT"
expect deny "tag onto a branch (src:dst)" "${CDW}git push origin refs/tags/v1:refs/heads/main"
expect deny "tag to tag (src:dst)" "${CDW}git push origin refs/tags/v1:refs/tags/v1"
expect deny "wildcard refspec" "${CDW}git push origin 'refs/tags/*'"
expect deny "no remote" "${CDW}git push refs/tags/v1"
expect deny "chained after a re-tag (moves the tag after the check)" "${CDW}git tag -f v1 feature && git push origin refs/tags/v1"
expect deny "chained before another command" "${CDW}git push origin refs/tags/v1 && echo done"
expect deny "split by a newline into a branch push" "${CDW}git push origin
refs/tags/v1"
expect deny "command substitution in the name" "${CDW}git push origin refs/tags/\$(echo v1)"
expect deny "environment assignment" "${CDW}GIT_DIR=.git git push origin refs/tags/v1"
expect deny "git -c" "${CDW}git -c push.followTags=true push origin refs/tags/v1"
expect deny "git -C" "${CDW}git -C . push origin refs/tags/v1"
expect deny "uppercase executable" "${CDW}GIT push origin refs/tags/v1"
expect deny "quoted tag ref" "${CDW}git push origin \"refs/tags/v1\""

echo ""
echo "--- denied: branch pushes without a marker, from a branch with commits ---"
git -C "$W" checkout -q feature
expect deny "branch by name" "git push origin feature" "$TAG_HINT"
expect deny "HEAD" "git push origin HEAD"
expect deny "bare push" "git push"
expect deny "remote only" "git push origin"
expect deny "branch with --follow-tags" "git push --follow-tags origin feature"
expect deny "branch by name, after the cd" "${CDW}git push origin feature" "$TAG_HINT"
# The case this route exists for: a release tag pushed while an unreviewed branch is checked out.
expect allow "a merged tag, from a checkout of an unreviewed branch" "${CDW}git push origin refs/tags/v1"
git -C "$W" checkout -q main

echo ""
echo "--- the route is refused while a remote.<name>.push refspec could redirect it ---"
# WHY: git maps a refs/tags/<t> with no :<dst> onto a configured push refspec's destination,
# which can be a branch, with its force flag (git-push(1), <refspec>).
git -C "$W" config remote.origin.push '+refs/tags/*:refs/heads/*'
expect deny "a merged tag, with remote.origin.push configured" "${CDW}git push origin refs/tags/v1" "$TAG_HINT"
git -C "$W" config --unset remote.origin.push

echo ""
echo "--- a replace graft does not make an unreviewed commit look merged ---"
# WHY: `git replace --graft` changes what merge-base sees, while the pack a push sends ignores
# replace refs (measured 2026-10-30, git 2.39), so the check runs with --no-replace-objects.
ORIGIN_MAIN=$(git -C "$W" rev-parse refs/remotes/origin/main)
git -C "$W" replace --graft "$ORIGIN_MAIN" "$(git -C "$W" rev-parse 'refs/tags/vbad^{commit}')"
git -C "$W" merge-base --is-ancestor refs/tags/vbad refs/remotes/origin/main
assert_exit_zero "$?" "the graft makes plain merge-base report vbad as merged (fixture check)"
expect deny "an unreviewed tag behind a replace graft" "${CDW}git push origin refs/tags/vbad" "$TAG_REASON"
git -C "$W" replace -d "$ORIGIN_MAIN" >/dev/null

echo ""
echo "--- the ancestry check reads refs/remotes/origin/main, not a look-alike branch ---"
# WHY: `origin/main` resolves to refs/heads/origin/main before refs/remotes/origin/main, so a
# local branch of that name would make any commit look merged.
git -C "$W" branch origin/main feature 2>/dev/null
git -C "$W" rev-parse --verify --quiet refs/heads/origin/main >/dev/null
assert_exit_zero "$?" "the look-alike branch origin/main exists (fixture check)"
expect deny "tag off main, with a local branch named origin/main on it" "${CDW}git push origin refs/tags/vbad" "$TAG_REASON"
git -C "$W" branch -D origin/main >/dev/null 2>&1

echo ""
echo "--- refs/tags/<t> must exist as written, not as a look-alike ---"
# WHY: rev-parse resolves refs/tags/ghost to refs/heads/refs/tags/ghost when no such tag exists,
# and git push sends that as a branch. It is on main here, so only show-ref --verify stops it.
git -C "$W" branch refs/tags/ghost main 2>/dev/null
git -C "$W" rev-parse --verify --quiet "refs/tags/ghost^{commit}" >/dev/null
assert_exit_zero "$?" "rev-parse resolves refs/tags/ghost through the look-alike branch (fixture check)"
expect deny "a branch named refs/tags/ghost, on main" "${CDW}git push origin refs/tags/ghost" "$TAG_REASON"
git -C "$W" branch -D refs/tags/ghost >/dev/null 2>&1

echo ""
echo "--- refs/tags/<t> must not be a symbolic ref ---"
# WHY: git pushes a symref under refs/tags/ as the branch it points to (measured with git 2.55:
# `* [new branch] sym -> feat`), so this would be a branch push with no marker. Pointed at main
# here, so only the symbolic-ref check stops it.
git -C "$W" symbolic-ref refs/tags/sym refs/heads/main
git -C "$W" symbolic-ref -q refs/tags/sym >/dev/null
assert_exit_zero "$?" "refs/tags/sym is a symbolic ref (fixture check)"
expect deny "a symbolic ref under refs/tags/ to a branch on main" "${CDW}git push origin refs/tags/sym" "$TAG_REASON"
git -C "$W" update-ref -d --no-deref refs/tags/sym

echo ""
echo "--- the cd path is an ASCII allowlist ---"
# WHY: anything in the cd path that the shell reads differently from the hook's literal resolution
# lets a command re-point the tag after the check, or check one repository and push from another:
#   * bash and pwsh run $(...) and backticks inside double quotes
#   * '\' escapes a quote in bash
#   * pwsh's cd expands wildcards
#   * pwsh ends a string at typographic quotes such as ’ and ” (measured 2026-10-26: such a
#     row was allowed by the .ps1 twin)
# Each directory exists under its literal name, so the twins resolve the path (except where a
# comment below says otherwise), and only the cd-path classes in TAG_PUSH stop these rows. The needle is the marker-path hint, so a deny for
# any other reason (an unresolvable path, say) fails the row. Nothing here is executed.
SUBST_DIR='$(git tag -f v1 feature)'
TICK_DIR='`git tag -f v1 feature`'
RSQ_DIR="q$(printf '\342\200\231')s"   # U+2019, which pwsh reads as a single quote
RDQ_DIR="q$(printf '\342\200\235')d"   # U+201D, which pwsh reads as a double quote
WILD_DIR='[ab]'
mkdir -p "$W/$SUBST_DIR" "$W/$TICK_DIR" "$W/$RSQ_DIR" "$W/$RDQ_DIR" "$W/$WILD_DIR"
# A path that keeps the absolute C:/ or / start, so only the '\' in it can fail the shape: on
# Windows a separator (w\bs), elsewhere a literal name (w/b\s).
if command -v cygpath >/dev/null 2>&1; then
  mkdir -p "$W/bs"
  BS_DIR="$W/bs"
  BS_PATH="$(native "$W")\\bs"
else
  mkdir -p "$W/b\\s"
  BS_DIR="$W/b\\s"
  BS_PATH="$W/b\\s"
fi
[ -d "$W/$SUBST_DIR" ] && [ -d "$W/$TICK_DIR" ] && [ -d "$W/$RSQ_DIR" ] && [ -d "$W/$RDQ_DIR" ] \
  && [ -d "$W/$WILD_DIR" ] && [ -d "$BS_DIR" ]
assert_exit_zero "$?" "the literal-name cd directories exist (fixture check)"
expect deny "command substitution in a quoted cd path" "cd \"$(native "$W")/$SUBST_DIR\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "command substitution in a single-quoted cd path" "cd '$(native "$W")/$SUBST_DIR' && git push origin refs/tags/v1" "$TAG_HINT"
# WHY ps1 skips the needle here off Windows (measured 2026-10-30, pwsh 7.4 on Debian): pwsh on
# Unix reads '\' as a separator, so w/b\s does not resolve and it denies before the tag route,
# which fails closed.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) NEEDLE_SKIP_TWIN=ps1 ;; esac
expect deny "a backslash in a quoted cd path" "cd \"$BS_PATH\" && git push origin refs/tags/v1" "$TAG_HINT"
NEEDLE_SKIP_TWIN=""
# WHY the sh twin skips the needle for these four on Windows only (measured 2026-10-30, Git Bash):
# it denies them before reaching the tag route, and so for another reason. A backtick or '[' path
# makes `git -C` fail ("could not resolve a repository from the command's explicit path"). Python
# prints a non-ASCII path in cp1252, so bash cannot cd to it ("cannot resolve the command's
# explicit repository path"). Both fail closed. On Windows the ps1 rows carry the proof, and on
# Linux both twins do.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) NEEDLE_SKIP_TWIN=sh ;; esac
expect deny "backticks in a quoted cd path" "cd \"$(native "$W")/$TICK_DIR\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "a typographic single quote in a single-quoted cd path" "cd '$(native "$W")/$RSQ_DIR' && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "a typographic double quote in a quoted cd path" "cd \"$(native "$W")/$RDQ_DIR\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "a wildcard in a cd path" "cd '$(native "$W")/$WILD_DIR' && git push origin refs/tags/v1" "$TAG_HINT"
NEEDLE_SKIP_TWIN=""

echo ""
echo "--- the cd must be exactly one, to an absolute path ---"
# WHY: bash and pwsh read a leading '-', '+' or '~' as the previous directory, location history or
# HOME, and a relative path or a second cd resolves against two different directories. The ps1
# hook would read each as a literal folder (a draft that allowed them let `cd "<A>" && cd "-"`
# through while the shell pushed from another repository, 2026-10-30). A decoy directory of each
# name exists in the hook's working directory. In ps1 these rows are stopped by both the shape and
# the fully-qualified check, so only a mutant that removes both shows them discriminating.
mkdir -p "$W/-" "$W/--" "$W/-P" "$W/~" "$W/+" "$W/sub"
[ -d "$W/-" ] && [ -d "$W/--" ] && [ -d "$W/-P" ] && [ -d "$W/~" ] && [ -d "$W/+" ] && [ -d "$W/sub" ]
assert_exit_zero "$?" "the decoy cd directories exist (fixture check)"
# sh skips the needle on these four: bash resolves them to OLDPWD or HOME, so it denies earlier,
# for another reason.
NEEDLE_SKIP_TWIN=sh
expect deny "cd \"-\" (the previous directory)" "cd \"-\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "cd '-' (the previous directory)" "cd '-' && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "cd \"--\"" "cd \"--\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "cd \"-P\"" "cd \"-P\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "an absolute cd and then cd \"-\"" "${CDW}cd \"-\" && git push origin refs/tags/v1" "$TAG_HINT"
NEEDLE_SKIP_TWIN=""
# bash reads a quoted ~ and a + literally, so both twins reach the shape check here, except that
# on Windows Git Bash cannot hand git -C a path with a ~ component, so sh denies the ~ row
# earlier there (measured 2026-10-31).
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) NEEDLE_SKIP_TWIN=sh ;; esac
expect deny "cd \"~\" (HOME in pwsh)" "cd \"~\" && git push origin refs/tags/v1" "$TAG_HINT"
NEEDLE_SKIP_TWIN=""
expect deny "cd \"+\" (location history in pwsh)" "cd \"+\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "a relative cd" "cd \"sub\" && git push origin refs/tags/v1" "$TAG_HINT"
expect deny "a relative single-quoted cd" "cd 'sub' && git push origin refs/tags/v1" "$TAG_HINT"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *)
    # WHY off Windows only: there C:/x is a relative path (a directory named C:), which the shape
    # accepts as absolute. Both twins refuse the tag route for it.
    mkdir -p "$W/C:/x"
    expect deny "a C:/ cd off Windows, which is relative there" "cd \"C:/x\" && git push origin refs/tags/v1" "$TAG_HINT"
    ;;
esac
expect deny "two cds" "${CDW}cd \"$(native "$W")\" && git push origin refs/tags/v1" "$TAG_HINT"
if command -v cygpath >/dev/null 2>&1 && command -v pwsh >/dev/null 2>&1; then
  # WHY ps1 only: on Windows a /... path is rooted but not fully qualified. pwsh resolves it on the
  # current drive, so "/Users/.../w" (this repository without its C:) is this repository to the
  # hook, while Git Bash looks under its own root and finds nothing there. The ps1 twin refuses
  # the tag route for any such path, so the marker path denies it.
  NODRIVE_W=$(native "$W" | sed 's/^[A-Za-z]://')
  out=$(run_hook ps1 "cd \"$NODRIVE_W\" && git push origin refs/tags/v1")
  assert_contains "$(printf '%s' "$out" | reason_of)" "$TAG_HINT" "[ps1] a drive-less /... cd is not fully qualified on Windows, so it takes the marker path"
fi

echo ""
echo "--- the hook enters the resolved root literally, not as a wildcard ---"
# WHY: the cd path names a link to S/[ab]/repo, whose v1 is unreviewed, beside S/a/repo, whose v1
# is merged. git resolves the root as .../[ab]/repo. A plain pwsh Set-Location expands [ab] and
# lands in .../a/repo (measured 2026-10-30, pwsh 7, Windows and Debian), so the tag route checked
# the wrong repository and allowed. The shell pushes from [ab]/repo.
# Native paths for git: Git Bash does not convert an MSYS path holding [ for git.exe.
S41=$(native "$TMP_TP/s41")
mkdir -p "$S41/a" "$S41/[ab]"
git clone -q -b main "$(native "$TMP_TP/origin.git")" "$S41/a/repo" 2>/dev/null
git -C "$S41/a/repo" tag v1
git clone -q -b main "$(native "$TMP_TP/origin.git")" "$S41/[ab]/repo" 2>/dev/null
git -C "$S41/[ab]/repo" config user.email "test@example.com"
git -C "$S41/[ab]/repo" config user.name "Test"
git -C "$S41/[ab]/repo" commit -q --allow-empty -m "unreviewed"
git -C "$S41/[ab]/repo" tag v1
if command -v cygpath >/dev/null 2>&1; then
  # A junction needs no administrator rights, unlike a Windows symlink.
  MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$S41/link")" "$(cygpath -w "$S41/[ab]/repo")" >/dev/null 2>&1
else
  ln -s "$S41/[ab]/repo" "$S41/link"
fi
git -C "$S41/a/repo" merge-base --is-ancestor v1 refs/remotes/origin/main \
  && ! git -C "$S41/[ab]/repo" merge-base --is-ancestor v1 refs/remotes/origin/main \
  && [ -e "$S41/link/.git" ]
assert_exit_zero "$?" "a/repo's v1 is merged, [ab]/repo's is not, and the link reaches [ab]/repo (fixture check)"
# The sh twin denies too, but on Windows Git Bash cannot open the [ab] path it resolves, so it
# denies for another reason there.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) NEEDLE_SKIP_TWIN=sh ;; esac
expect deny "a cd through a link to a [ab] repository beside an a repository" "cd \"$S41/link\" && git push origin refs/tags/v1" "$TAG_REASON"
NEEDLE_SKIP_TWIN=""

echo ""
echo "--- the two classifiers carry the same pattern text ---"
# WHY: TAG_PUSH and TAG_PUSH_NAME are written once in each language, and only these rows notice
# when one copy is edited without the other.
pattern_text() {
  # pattern_text py|ps1 shape|name
  python3 -I -c '
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
if sys.argv[2] == "py":
    name = "TAG_PUSH" if sys.argv[3] == "shape" else "TAG_PUSH_NAME"
    m = re.search(r"^" + name + r" = re\.compile\(r\x27\x27\x27(.*?)\x27\x27\x27\)$", src, re.M)
else:
    var = "shapeText" if sys.argv[3] == "shape" else "nameText"
    m = re.search(r"\$" + var + r" = @\x27\r?\n(.*?)\r?\n\x27@", src)
print(m.group(1) if m else "<not found>")
' "$REPO_ROOT/scripts/_review-gate-classify.$1" "$1" "$2"
}
for part in shape name; do
  py_text=$(pattern_text py "$part")
  assert_not_contains "$py_text" "<not found>" "the .py $part pattern is found (fixture check)"
  assert_equals "$(pattern_text ps1 "$part")" "$py_text" "the .ps1 $part pattern text equals the .py one"
done

echo ""
echo "--- [sh] a fallback verdict does not take the tag route even when --tag-push could answer ---"
# WHY: --tag-push skips the verdict computation, so it can answer when that computation failed.
# This stub python3 fails every call except --tag-push, making the verdict a fallback PUSH.
REALPY=$(command -v python3)
STUB="$TMP_TP/stubbin"
mkdir -p "$STUB"
printf '%s\n' '#!/bin/sh' "[ \"\$2\" = --tag-push ] && exec \"$REALPY\" \"\$@\"" 'exit 1' > "$STUB/python3"
chmod +x "$STUB/python3"
# Called exactly as the hook calls it: python3 <classifier> [--tag-push].
out=$(payload "${CDW}git push origin refs/tags/v1" 2>/dev/null | "$STUB/python3" "$REPO_ROOT/scripts/_review-gate-classify.py" --tag-push 2>/dev/null | tr -d '\r')
assert_equals "$out" "$(printf 'TAG-PUSH\nv1')" "the stub still answers --tag-push (fixture check)"
payload "${CDW}git push origin refs/tags/v1" 2>/dev/null | "$STUB/python3" "$REPO_ROOT/scripts/_review-gate-classify.py" >/dev/null 2>&1
assert_exit_nonzero "$?" "the stub fails the plain verdict call (fixture check)"
out=$(payload "${CDW}git push origin refs/tags/v1" 2>/dev/null | (cd "$W" && PATH="$STUB:$PATH" bash "$REPO_ROOT/scripts/review-reminders.sh" 2>/dev/null))
assert_contains "$out" '"permissionDecision":"deny"' "[sh] a fallback verdict denies a tag push the classifier would have let through"

echo ""
echo "--- [sh] a classifier from before --tag-push does not open the route ---"
# WHY: an older classifier ignores --tag-push and prints its verdict, PUSH. Without the TAG-PUSH
# header the hook read that as a tag name, so a tag literally named PUSH on main let any push
# through. This stand-in prints PUSH for every call except --git-context, as the old one did.
OLDCLS="$TMP_TP/oldcls"
mkdir -p "$OLDCLS"
cp "$REPO_ROOT/scripts/review-reminders.sh" "$REPO_ROOT/scripts/_review-gate-lib.sh" "$OLDCLS/"
printf '%s\n' 'import sys' 'sys.stdin.read()' "if '--git-context' not in sys.argv:" "    sys.stdout.write('PUSH')" \
  > "$OLDCLS/_review-gate-classify.py"
git -C "$W" tag PUSH main
out=$(payload "git push origin main" | (cd "$W" && bash "$OLDCLS/review-reminders.sh" 2>/dev/null))
assert_contains "$out" '"permissionDecision":"deny"' "[sh] an old classifier's PUSH is not read as a tag name, even with a tag named PUSH on main"
git -C "$W" tag -d PUSH >/dev/null

echo ""
echo "--- the hook runs its own classifier, invoked by a relative path as settings.json does ---"
# WHY: settings.json runs `bash scripts/review-reminders.sh`, so a "$(dirname "$0")" evaluated
# after the hook's cd into the target repository named THAT repository's scripts/ (measured
# 2026-10-30). This target carries a classifier that answers every --tag-push with a merged tag;
# if the hook ran it, the branch push below would be allowed with no marker.
mkdir -p "$W/scripts"
printf '%s\n' 'import sys' 'sys.stdin.read()' "sys.stdout.write('TAG-PUSH\\nv1' if '--tag-push' in sys.argv else 'PUSH')" \
  > "$W/scripts/_review-gate-classify.py"
out=$(payload "${CDW}git push origin feature" 2>/dev/null | (cd "$REPO_ROOT" && bash scripts/review-reminders.sh 2>/dev/null))
assert_contains "$(printf '%s' "$out" | reason_of)" "$TAG_HINT" "[sh] run relatively, the hook ignores the target repository's classifier and denies the branch push"
# No ps1 row: the .ps1 hook loads its classifier through $PSScriptRoot before it changes
# directory, so a planted target classifier cannot reach it.
rm -f "$W/scripts/_review-gate-classify.py"
rmdir "$W/scripts"

echo ""
echo "--- classifier unavailable: a tag push falls back to the marker ---"
# A copy of the scripts without the classifier: the verdict comes from the raw fallback, which
# carries no refspecs, so it must not open the tag route.
NOCLS="$TMP_TP/nocls"
mkdir -p "$NOCLS"
cp "$REPO_ROOT/scripts/review-reminders.sh" "$REPO_ROOT/scripts/review-reminders.ps1" \
   "$REPO_ROOT/scripts/_review-gate-lib.sh" "$REPO_ROOT/scripts/_review-gate-lib.ps1" "$NOCLS/"
out=$(payload "${CDW}git push origin refs/tags/v1" 2>/dev/null | (cd "$W" && bash "$NOCLS/review-reminders.sh" 2>/dev/null))
assert_contains "$out" '"permissionDecision":"deny"' "[sh] a fallback verdict does not take the tag route"
if command -v pwsh >/dev/null 2>&1; then
  out=$(payload "${CDW}git push origin refs/tags/v1" 2>/dev/null | (cd "$W" && pwsh -NonInteractive -File "$NOCLS/review-reminders.ps1" 2>/dev/null))
  assert_contains "$out" '"permissionDecision":"deny"' "[ps1] a fallback verdict does not take the tag route"
fi

echo ""
echo "--- template mirrors ---"
for f in review-reminders.sh review-reminders.ps1 _review-gate-classify.py _review-gate-classify.ps1; do
  diff -q "$REPO_ROOT/scripts/$f" "$REPO_ROOT/templates/scripts/$f" >/dev/null 2>&1
  assert_exit_zero "$?" "templates/scripts/$f is byte-identical to scripts/$f"
done

if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
  command -v pwsh >/dev/null 2>&1 || assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH -- the ps1 rows did not run"
fi

print_summary
