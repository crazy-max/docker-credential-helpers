# syntax=docker/dockerfile:1.3-labs
ARG GO_VERSION=1.16

FROM golang:${GO_VERSION}-alpine AS vendored
RUN  apk add --no-cache git rsync
WORKDIR /src
RUN --mount=target=/context \
  --mount=target=.,type=tmpfs,readwrite  \
  --mount=target=/go/pkg/mod,type=cache <<EOT
set -e
rsync -a /context/. .
go mod tidy
go mod vendor
mkdir /out
cp -r go.mod go.sum vendor /out
EOT

FROM scratch AS update
COPY --from=vendored /out /out

FROM vendored AS validate
RUN --mount=target=/context \
  --mount=target=.,type=tmpfs,readwrite <<EOT
set -e
rsync -a /context/. .
git add -A
rm -rf vendor
cp -rf /out/* .
if [ -n "$(git status --porcelain -- go.mod go.sum vendor)" ]; then
  echo >&2 'ERROR: Vendor result differs. Please vendor your package with "make vendor"'
  git status --porcelain -- go.mod go.sum vendor
  exit 1
fi
EOT
