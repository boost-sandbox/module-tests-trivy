#!/bin/sh

set -e
set -u

export BOOST_TMP_DIR BOOST_CLI_DIR
BOOST_CLI_URL=${BOOST_CLI_URL:-"https://assets.build.boostsecurity.io"}
BOOST_CLI_VERSION=${BOOST_CLI_VERSION:-1}
BOOST_TMP_DIR="${BOOST_TMP_DIR:-${WORKSPACE_TMP:-${TMPDIR:-/tmp}}}"
BOOST_TMP_DIR=${BOOST_TMP_DIR%*/}
_BOOST_CLI_BASE=${BOOST_TMP_DIR}/boost-cli


info ()
{ # $@=message
  printf "$(date +'%H:%M:%S') [\033[34m%s\033[0m] %s\n" "INFO" "${*}"
}

error ()
{ # $@=message
  printf "$(date +'%H:%M:%S') [\033[31m%s\033[0m] %s\n" "ERROR" "${*}" 1>&2
}

get_http_cli ()
{
  if command -v curl > /dev/null; then
    echo "curl"
  elif command -v wget > /dev/null; then
    echo "wget"
  else
    error "unable to download boost.sh neither curl nor wget detected"
    exit 1
  fi
}

get_http_metadata ()
{ # $1=cmd, $2=url
  case "${1}" in
    curl)
      curl --silent -H "Cache-Control: no-cache" -I "${2}" 2> /dev/null \
        | grep -Fi -e x-amz-meta-version \
        | sort \
        | cut -f2 -d\ \
        | tr -d \" \
        | tr -d \\r \
        | tr -d "[:blank:]" \
        || true
      ;;
    wget)
      wget --no-cache --quiet --spider --server-response "${2}" 2>&1 \
        | grep -Fi -e x-amz-meta-version \
        | sort \
        | cut -f2 -d: \
        | tr -d \" \
        | tr -d \\r \
        | tr -d "[:blank:]" \
        || true
  esac
}

get_index_metadata ()
{ # $1=cmd, $2=url, $3=version
  get_http_metadata "${1}" "${2}/index/${3}"
}

get_asset_metadata ()
{ # $1=cmd, $2=url, $3=version
  get_http_metadata "${1}" "${2}/${3}/boost-cli"
}

get_head_metadata ()
{ # $1=cmd, $2=url, $3=version
  _metadata=$(get_index_metadata "${1}" "${2}" "${3}")

  if test -z "${_metadata}"; then
    _metadata=$(get_asset_metadata "${1}" "${2}" "${3}")
  fi

  if test -z "${_metadata}"; then
    error "failed downloading url with ${1} from ${2}"
    exit 2
  fi

  echo "${_metadata}"
}

get_binary ()
{ # $1=cmd, $2=url, $3=version, $4=target
  mkdir -p "$(dirname "${4}")"
  runner="${4}"/runner
  url="${2}/${3}/boost-cli"

  case "${1}" in
    curl)
      if ! curl --fail --location --silent --output "${runner}" "${url}"; then
        error "failed downloading url with ${1} from ${url}"
        exit 2
      fi
      ;;
    wget)
      if ! wget --quiet -O "${runner}" "${url}"; then
        error "failed downloading url with ${1} from ${url}"
        exit 2
      fi
  esac

  # shellcheck disable=SC2064
  chmod 755 "${runner}"
  "${runner}" version > /dev/null
}

download ()
{ # $1=url, $2=version, $3=cli_dir
  cmd=$(get_http_cli)
  version=$(echo "${2}" | sed -e 's@+@%2B@')
  metadata=$(get_head_metadata "${cmd}" "${1}" "${version}")
  version=$(echo "${metadata}" | head -n1 | sed -e 's@+@%2B@')

  export BOOST_CLI_DIR="${3}/${version}"
  mkdir -p "${BOOST_CLI_DIR}"

  if test -e "${BOOST_CLI_DIR}/runner"; then
    info "downloading boost cli skipped, detected current version"
  else
    info "downloading boost cli"
    mkdir -p "${3}"
    get_binary "${cmd}" "${1}" "${version}" "${BOOST_CLI_DIR}"
  fi

  ln -snf "${BOOST_CLI_DIR}/runner" "${3}/latest"
}

cleanup ()
{ # $1=cli_dir
  now=$(date +%s)
  target=$((now - 28800))  # files older than 8 hour

  if [ "$(find "${1}" -mindepth 1 -maxdepth 1 -type d | wc -l)" -lt 3 ]; then
    return
  fi

  for path in "${1}"/*; do
    if [ "${path}" -ef "${1}/latest" ]; then
      continue
    fi

    if [ "${path}" = "${1}/latest" ]; then
      continue
    fi

    if [ ! -d "${path}" ]; then
      continue
    fi

    if [ "$(stat -c "%Y" "${path}")" -lt "${target}" ]; then
      info "deleting previous installed version $(dirname "${path}")"
      rm -rf "${path}"
    fi
  done
}

main ()
{ # [$1=version]
  uname_arch=${BOOST_CLI_ARCH:-$(uname -m)}
  boost_url=${BOOST_CLI_URL%*/}/boost-cli
  boost_url="${boost_url}/linux/${uname_arch}"

  if ! test -d "${_BOOST_CLI_BASE}"; then
    if ! mkdir -p "${_BOOST_CLI_BASE}"; then
      error "failed to create tmp dir in ${_BOOST_CLI_BASE}"
      exit 2
    fi
  fi

  download "${boost_url}" "${1:-${BOOST_CLI_VERSION}}" "${_BOOST_CLI_BASE}"
  cleanup "${_BOOST_CLI_BASE}"

  if ! "${BOOST_CLI_DIR}/runner" version > /dev/null; then
    error "unable to launch downloaded cli"
    exit 3
  fi
}

usage ()
{
  cat <<EOF
usage: $(basename "$0") [VERSION] [--help]

  Downloads the BoostSecurity CLI

parameters:

  --help:     Print this help page.

  VERSION:    The version to download

              May be provided on the CLI or using the BOOST_CLI_VERSION
              environment variable.

              Defaults to ${BOOST_CLI_VERSION}

environment:

  BOOST_TMP_DIR:  The temporary directory to download into

              If undefined, we will attempt to inspect the environment to determine
              the correct location. This will be either within WORKSPACE_TMP,
              TMPDIR or /tmp.

              Defaults to ${BOOST_TMP_DIR}

EOF
}

if [ ${#} -gt 1 ]; then
  usage
  exit 1
fi

if [ "${*:-}" = "--help" ]; then
  usage
  exit 0
fi

main "${1:-}"
