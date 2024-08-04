# syntax=docker/dockerfile:1.4
# NOTE: build root is the root of the repo

ARG BUILD_IMAGE_BASE="alpine:3.20"
ARG JQ_VERSION="1.7.1"
ARG OQ_BIN_DIR="/opt/oq/bin"
ARG OQ_BIN_USE_TARGETARCH="false"

FROM ${BUILD_IMAGE_BASE} as build-base
RUN apk add \
      --update \
      --upgrade \
      --no-cache \
      --force-overwrite \
      crystal shards \
      git bash curl jq \
      libxml2-dev libxml2-static yaml-dev yaml-static xz-static zlib-static

FROM build-base as build
ARG JQ_VERSION OQ_BIN_DIR OQ_BIN_USE_TARGETARCH TARGETARCH
WORKDIR /src
SHELL ["/bin/bash", "-uo", "pipefail", "-c"]
RUN --mount=type=bind,source=.,target=/src,rw <<-SCRIPT
    #!/usr/bin/env bash
    mkdir -p "${OQ_BIN_DIR}"
    echo >&2 "## downloading jq"
    JQ_REPO="jqlang/jq"
    if [[ -z "${JQ_VERSION:-}" ]] || [[ "${JQ_VERSION}" == "latest" ]]; then
      JQ_VERSION="$(curl -sSLq "https://api.github.com/repos/${JQ_REPO}/releases/latest" | jq -r .tag_name)"
    fi
    echo "### JQ_VERSION: ${JQ_VERSION}"
    wget -qO "${OQ_BIN_DIR}/jq" \
      "https://github.com/${JQ_REPO}/releases/download/jq-${JQ_VERSION}/jq-linux-${TARGETARCH}"
    chmod +x "${OQ_BIN_DIR}/jq"
    "${OQ_BIN_DIR}/jq" --version || exit 1
    echo >&2 "## resolving OQ version"
    OQ_VERSION="$(git describe --exact-match --tags HEAD 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
      echo >&2 "### the HEAD is tagged"
    else
      echo >&2 "### the HEAD is not tagged"
      OQ_VERSION="$(git rev-parse --short=8 HEAD)"
      if [[ $? -ne 0 ]]; then
        echo >&2 "### failed to get the SHA of the HEAD"
        exit 1
      fi
    fi
    if ! git diff --quiet; then
      OQ_VERSION+="-dirty"
    fi
    if [[ "${OQ_BIN_USE_TARGETARCH}" == "true" ]]; then
      echo >&2 "## using TARGETARCH in oq binary name"
      OQ_BIN="${OQ_BIN_DIR}/oq-${OQ_VERSION}-linux-${TARGETARCH}"
    else
      OQ_BIN="${OQ_BIN_DIR}/oq-${OQ_VERSION}-linux-$(uname -m)"
    fi
    echo >&2 "## building oq ${OQ_VERSION} for linux/${TARGETARCH}"
    shards build \
      --production \
      --release \
      --static \
      --no-debug \
      --link-flags="-s -Wl,-z,relro,-z,now"
    mv ./bin/oq ${OQ_BIN}
    ln -s ${OQ_BIN} /usr/local/bin/oq
    echo >&2 "## verifying OQ binary and checking version"
    oq --version
SCRIPT

FROM busybox:stable-musl as release
ARG OQ_BIN_DIR
COPY --link --from=build ${OQ_BIN_DIR}/* /usr/local/bin/
RUN cd /usr/local/bin && find . -type f -executable -name "oq*" -exec ln -s {} oq \;
USER nobody
ENTRYPOINT ["oq"]
