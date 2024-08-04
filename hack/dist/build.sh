#!/usr/bin/env bash
set -euo pipefail

export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

: ${TARGET_ARCH_LIST:='["arm64","amd64"]'}
export TARGET_ARCH_LIST=( $(jq -r .[] <<< ${TARGET_ARCH_LIST}) )

if [[ "${GITHUB_ACTIONS:-"false"}" == "true" ]]; then
  GA_GROUP_BEGIN="::group::"
  GA_GROUP_END="::endgroup::"
else
  GA_GROUP_BEGIN="## "
fi

echo >&2 "## TARGET_ARCH_LIST: ${TARGET_ARCH_LIST[@]}"

for arch in ${TARGET_ARCH_LIST[@]}; do
  echo "${GA_GROUP_BEGIN}building for linux/${arch}"
  docker build \
    --platform linux/${arch} \
    -t oq:${arch} \
    -f hack/dist/dist.Dockerfile \
    .
  echo "${GA_GROUP_END:-}"
done

[[ -d ./bin ]] || mkdir ./bin

for arch in ${TARGET_ARCH_LIST[@]}; do
  echo "${GA_GROUP_BEGIN}retrieving oq binary for linux/${arch}"
  docker run \
    --platform linux/${arch} \
    --rm \
    --user root \
    --entrypoint /bin/sh \
    --volume ${PWD}/bin:/mnt/repo/bin \
    --workdir /mnt/repo \
    oq:${arch} \
    -c 'cp -v "$(realpath $(which oq))" ./bin/'
    echo "${GA_GROUP_END:-}"
done

echo "${GA_GROUP_BEGIN}listing content of ./bin"
ls -la ./bin
echo "${GA_GROUP_END:-}"
