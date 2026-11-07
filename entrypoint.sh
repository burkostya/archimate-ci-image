#!/bin/bash

[ "${DEBUG:-false}" = true ] && set -x
set -euo pipefail

# Vars
# ----

# Script environments
: "${ARCHI_PROJECT_PATH:=${GITHUB_WORKSPACE:-${CI_PROJECT_DIR:-/archi/project}}}"
: "${ARCHI_REPORT_PATH:=/archi/report}"
: "${ARCHI_HTML_REPORT_ENABLED:=true}"
: "${ARCHI_JASPER_REPORT_ENABLED:=false}"
: "${ARCHI_JASPER_REPORT_FORMATS:=PDF,DOCX}"
: "${ARCHI_CSV_REPORT_ENABLED:=false}"
: "${ARCHI_EXPORT_MODEL_ENABLED:=true}"
: "${ARCHI_APP:=com.archimatetool.commandline.app}"
: "${ARCHI_EXTRA_ARGS:=}"

: "${GITHUB_SERVER_URL:=https://github.com}"
: "${GITHUB_PAGES_BRANCH:=gh-pages}"
: "${GIT_SUBTREE_PREFIX:=.archi_report}"

# Tools environments
declare -a _ssh_args=(
  -o BatchMode=yes
  -o UserKnownHostsFile=/dev/null
  -o StrictHostKeyChecking=no
)
GIT_SSH_COMMAND="ssh ${_ssh_args[*]}"
GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND GIT_TERMINAL_PROMPT

# Functions
# ---------

# Run Archi
archi_run() {
  local -a _args=()
  local -a _dirs=()

  # Html report
  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --html.createReport
        "${ARCHI_HTML_REPORT_PATH:=$ARCHI_REPORT_PATH/html}"
    ) && _dirs+=("$ARCHI_HTML_REPORT_PATH")

  # CSV report
  [ "${ARCHI_CSV_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --csv.export
        "${ARCHI_CSV_REPORT_PATH:=$ARCHI_REPORT_PATH/csv}"
    ) && _dirs+=("$ARCHI_CSV_REPORT_PATH")

  # Export model
  [ "${ARCHI_EXPORT_MODEL_ENABLED,,}" == true ] &&
    _args+=(
      --saveModel
        "${ARCHI_EXPORT_MODEL_PATH:=$ARCHI_REPORT_PATH}/$_project.archimate"
    ) && _dirs+=("$ARCHI_EXPORT_MODEL_PATH")

  # Jasper report
  [ "${ARCHI_JASPER_REPORT_ENABLED,,}" == true ] &&
    _args+=(
      --jasper.createReport
        "${ARCHI_JASPER_REPORT_PATH:=$ARCHI_REPORT_PATH/jasper}"
      --jasper.format
        "$ARCHI_JASPER_REPORT_FORMATS"
      --jasper.filename
        "$_project"
      --jasper.title
        "${ARCHI_JASPER_REPORT_TITLE:=$_project}"
    ) && _dirs+=("$ARCHI_JASPER_REPORT_PATH")

  # Some Archi exporters only log an unwritable destination and return success.
  # Create destinations here so filesystem errors fail the container first.
  local _dir
  for _dir in "${_dirs[@]}"; do
    mkdir -p "$_dir"
    [ -w "$_dir" ] || fail "Report directory is not writable: $_dir"
  done

  if [ -n "$ARCHI_EXTRA_ARGS" ]; then
    # shellcheck disable=SC2206  # we want word-splitting into array
    _args+=( $ARCHI_EXTRA_ARGS )
  fi

  # Run Archi
  dbus-run-session -- xvfb-run -a \
    /opt/Archi/Archi --launcher.suppressErrors -application "$ARCHI_APP" -consoleLog -nosplash \
      --abortOnException --modelrepository.loadModel "$ARCHI_PROJECT_PATH" "${_args[@]}" &&
  printf '\n%s\n\n' "Done. Reports saved to $ARCHI_REPORT_PATH"
}

# Check first argument match regex present in second argument
re_match() {
  local value="${1:-}" regex="${2:-.*}"
  [ -n "$value" ] && grep -Pq "$regex" <<<"$value" && return 0
  return 1
}

# Encode url symbols
urlencode() {
  # Percent encoding operates on UTF-8 bytes, including non-ASCII model names.
  local LC_ALL=C
  local length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:$i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
                    *) printf '%%%02X' "'$c" ;;
    esac
  done
}

insert_nav_right() {
  local file="$1" line="$2"
  awk -v ins="$line" '
    BEGIN { done=0; re_ul="class=[\"\x27][^\"\x27]*(navbar-right|navbar-end|ms-auto)[^\"\x27]*[\"\x27]" }
    $0 ~ /<ul[^>]*class=[\"\x27][^\"\x27]*nav[^\"\x27]*navbar-nav[^\"\x27]*[\"\x27]/ && done==0 && !match($0, re_ul) {
      print; print ins; done=1; next
    }
    $0 ~ /<ul[^>]*class=[\"\x27][^\"\x27]*(navbar-right|navbar-end|ms-auto)[^\"\x27]*[\"\x27]/ && done==0 {
      print; print ins; done=1; next
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Link to exports even when they are outside the HTML report directory.
report_link() {
  local html="$1" target="$2" label="$3" relative href
  relative="$(realpath -m --relative-to="$(dirname "$html")" "$target")"
  href="$(urlencode "$relative")"
  href="${href//%2F/\/}"
  grep -q ">${label}<" "$html" || \
    insert_nav_right "$html" "<li><a href=\"$href\" class=\"go\">$label</a></li>"
}

update_html() {
  local html_root="${ARCHI_HTML_REPORT_PATH:-$ARCHI_REPORT_PATH/html}"
  local html="$html_root/index.html"

  [ -f "$html" ] || return 0

  if [ "${ARCHI_CSV_REPORT_ENABLED,,}" == true ]; then
    for item in {elements,properties,relations}; do
      report_link "$html" "${ARCHI_CSV_REPORT_PATH:-$ARCHI_REPORT_PATH/csv}/${item}.csv" "${item^}"
    done
  fi

  if [ "${ARCHI_JASPER_REPORT_ENABLED,,}" == true ]; then
    for item in ${ARCHI_JASPER_REPORT_FORMATS//,/ }; do
      report_link "$html" "${ARCHI_JASPER_REPORT_PATH:-$ARCHI_REPORT_PATH/jasper}/$_project.${item,,}" "${item^^}"
    done
  fi

  if [ "${ARCHI_EXPORT_MODEL_ENABLED,,}" == true ]; then
    report_link "$html" "${ARCHI_EXPORT_MODEL_PATH:-$ARCHI_REPORT_PATH}/$_project.archimate" Model
  fi
}

# Git clone wrap
git_clone() { git clone "${1:?Repo url not set}" "$ARCHI_PROJECT_PATH"; }

# GitLab log separator
section_start () {
  printf '\e[0Ksection_start:%s:%s[collapsed=true]\r\e[0K\e[1;36m%s\e[0m\n' \
    "$(date +%s)" "$1" "${*:2}"
}
section_end () {
  printf '\e[0Ksection_end:%s:%s\r\e[0K\n' "$(date +%s)" "$*"
}

# Safe echo: hides secrets like tokens, passwords, etc.
smsg() {
  local msg="$*"
  local name secret esc

  for name in \
    GITHUB_TOKEN GIT_TOKEN GIT_PASSWORD CI_JOB_TOKEN \
    ACCESS_TOKEN AUTH_TOKEN TOKEN PASSWORD
  do
    secret="${!name:-}"
    [ -n "$secret" ] || continue
    # escape sed specials
    esc=$(printf '%s' "$secret" | sed -e 's/[\/&]/\\&/g')
    msg=$(printf '%s' "$msg" | sed "s/${esc}/***SECRET***/g")
  done

  printf '%s\n' "$msg"
}

# Fail message to stder and exit 1
fail() { printf >&2 '%s\n' "$*"; exit 1; }

is_ssh_repo() { [[ "$1" =~ ^[a-zA-Z0-9._-]+@[^:]+:.+\.git$ ]]; }
is_http_repo() { [[ "$1" =~ ^https?://.+\.git$ ]]; }

# Main
# ----

# Run custom archi command
if [ "$#" -ge 1 ]; then
  smsg "Execute Archi with _args: $*"
  dbus-run-session -- xvfb-run -a \
    /opt/Archi/Archi --launcher.suppressErrors -application "$ARCHI_APP" -consoleLog -nosplash --abortOnException "$@"
  exit 0
fi


# Get project title
if [ -f "$ARCHI_PROJECT_PATH/model/folder.xml" ]; then
  _project="$(
    grep -Pom1 'name="\K([^"]*)' \
      "$ARCHI_PROJECT_PATH/model/folder.xml" | \
      head -1
  )"
elif [ -n "${GIT_REPOSITORY:-}" ]; then
  _project="$(basename -s .git "$GIT_REPOSITORY")"
else
  _project='Model'
fi


# Run in GitHub actions
if [ "${GITHUB_ACTIONS:-}" == true ]; then
  echo "Run Archi report generation in GitHub actions"

  # Prepare vars
  : "${GITHUB_REPOSITORY:?Repository name not set}"

  [ "${DEBUG:-false}" != true ] && set +x;
  GITHUB_TOKEN="$(urlencode "${GITHUB_TOKEN:?Token not specified}")"
  [ "${DEBUG:-false}" = true ] && set -x

  # Create repository url with token
  # _gh_repo="${GITHUB_SERVER_URL//:\/\/*}://"                       # Protocol
  # _gh_repo+="x-access-token:$GITHUB_TOKEN@"                        # Auth
  # _gh_repo+="${GITHUB_SERVER_URL//*\/\/}/$GITHUB_REPOSITORY.git"   # URL

  # Set actions specified paths
  ARCHI_REPORT_PATH="$ARCHI_PROJECT_PATH/$GIT_SUBTREE_PREFIX"
  ARCHI_HTML_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_CSV_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_JASPER_REPORT_PATH="$ARCHI_REPORT_PATH"
  ARCHI_EXPORT_MODEL_PATH="$ARCHI_REPORT_PATH"
  cd "$ARCHI_PROJECT_PATH" && mkdir -p "$ARCHI_REPORT_PATH"

  # Create CNAME for custom domain
  [ -n "${GITHUB_PAGES_DOMAIN:-}" ] &&
    echo "$GITHUB_PAGES_DOMAIN" > "$ARCHI_REPORT_PATH/CNAME"

  # Disable Jekyll
  touch "$ARCHI_REPORT_PATH/.nojekyll"

  # Change git repo settings
  # git remote set-url origin "$_gh_repo"
  ! git config --get user.name >/dev/null &&
    git config --global user.name "${GITHUB_ACTOR:-nobody}"
  ! git config --get user.email >/dev/null &&
    git config --global user.email \
      "${GITHUB_ACTOR:-nobody}@users.noreply.${GITHUB_SERVER_URL//*\/\/}"
    git config --global --add safe.directory "$ARCHI_REPORT_PATH"
    git config --global --add safe.directory "$ARCHI_PROJECT_PATH"

  # Create report
  archi_run

  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] && update_html

  # Commit and push subtree
  git add --force "$GIT_SUBTREE_PREFIX"
  git commit --message \
    "Archimate report ${GITHUB_ACTION:-0}:${GITHUB_JOB:-0}" || \
    echo "Nothing to commit"

  _subtree="$(
    git subtree split --prefix \
      "$GIT_SUBTREE_PREFIX" "${GITHUB_REF_NAME:-HEAD}" || :
  )"
  [ -n "$_subtree" ] || fail "git subtree split returned empty sha"

  git push origin "$_subtree:refs/heads/$GITHUB_PAGES_BRANCH" --force

  exit 0

fi

# Run in GitLab CI
if [ "${GITLAB_CI:-}" == true ]; then
  echo "Run Archi report generation in GitLab CI"
  section_start 'archi_report' 'Render ArchiMate report'

  # Set actions specified paths
  ARCHI_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_HTML_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_CSV_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_JASPER_REPORT_PATH="$CI_PROJECT_DIR/public"
  ARCHI_EXPORT_MODEL_PATH="$CI_PROJECT_DIR/public"
  cd "$ARCHI_PROJECT_PATH" && mkdir -p "$ARCHI_REPORT_PATH"

  # Create report
  archi_run
  [ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] && update_html

  section_end 'Render ArchiMate report complete'
  exit 0
fi

# Check and use exist or mounted model
if [ -f "$ARCHI_PROJECT_PATH/model/folder.xml" ]; then
  smsg "Work with exist model in $ARCHI_PROJECT_PATH directory"
  # Try update exist model
  {
    git -C "$ARCHI_PROJECT_PATH" pull &>/dev/null &&
    smsg "Use actual state of model $_project."
  } || :


# Work with remote git repository model
elif [ -n "${GIT_REPOSITORY:-}" ]; then

  # Check URL is SSH and clone
  if is_ssh_repo "${GIT_REPOSITORY:-}"; then
    smsg "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir with ssh"
    git_clone "$GIT_REPOSITORY"

  # Check URL is HTTP
  elif is_http_repo "${GIT_REPOSITORY:-}"; then
    _proto="${GIT_REPOSITORY%%://*}"

    # Use token if set
    if [ -n "${GIT_TOKEN:-}" ]; then
      # Encode symbols
      GIT_TOKEN="$(urlencode "$GIT_TOKEN")"

      if re_match "${GIT_REPOSITORY:-}" '^https://github.com/'; then
        _auth="x-access-token:$GIT_TOKEN"
      else
        _auth="oauth2:$GIT_TOKEN"
      fi

      smsg \
        "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir use token"
      git_clone "$_proto://$_auth@${GIT_REPOSITORY#*://}"

    # Use login and password
    elif [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_PASSWORD:-}" ]; then
      # Encode symbols
      _auth="$(urlencode "$GIT_USERNAME"):$(urlencode "$GIT_PASSWORD")"

      smsg \
        "Clone model from $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir use token"
      git_clone "$_proto://$_auth@${GIT_REPOSITORY#*://}"

    # Use public repository access
    else
      smsg \
        "Clone model from repository $GIT_REPOSITORY to $ARCHI_PROJECT_PATH dir"
      git_clone "$GIT_REPOSITORY"

    fi

  # Git URL not valid
  else
    fail 'Git repository URL not valid. Please use http or ssh url'
  fi

# Exit. Model not exist
else
  smsg \
    "Please set http or ssh url to git repository in \$GIT_REPOSITORY" \
    "variable or mount model to \$ARCHI_PROJECT_PATH ($ARCHI_PROJECT_PATH)" \
    'directory.'
fi


# Make report
archi_run
[ "${ARCHI_HTML_REPORT_ENABLED,,}" == true ] && update_html
exit 0
