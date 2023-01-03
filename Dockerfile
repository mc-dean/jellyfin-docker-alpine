# syntax = docker/dockerfile:latest

ARG BUILDER_IMAGE_VERSION=6.0-alpine
FROM mcr.microsoft.com/dotnet/sdk:${BUILDER_IMAGE_VERSION} AS builder

RUN <<EOF
apk add bash icu-libs krb5-libs libgcc libintl libssl1.1 libstdc++ zlib git
apk add libgdiplus --repository https://dl-3.alpinelinux.org/alpine/edge/testing/
EOF

ARG JELLYFIN_VERSION=v10.8.8
WORKDIR /jellyfin

RUN <<EOF 
set -ex
git clone --branch ${JELLYFIN_VERSION} --depth 1 https://github.com/jellyfin/jellyfin.git .
dotnet publish Jellyfin.Server --configuration Release --self-contained --runtime linux-musl-x64 --output dist/ "-p:DebugSymbols=false;DebugType=none;UseAppHost=true"
mv ./dist /build
rm -rf /jellyfin
EOF

FROM node:16-alpine AS builder-web

RUN apk add git

ARG JELLYFIN_WEB_VERSION=v10.8.8

WORKDIR /jellyfin

RUN <<EOF
set -ex
git clone --branch ${JELLYFIN_WEB_VERSION} --depth 1 https://github.com/jellyfin/jellyfin-web.git .
npm ci
npm run build:production
mv ./dist /build
rm -rf /jellyfin
EOF

FROM alpine:3 AS runtime

RUN apk add libstdc++ icu-libs krb5-libs lttng-ust fontconfig ffmpeg

COPY --from=builder /build /jellyfin
COPY --from=builder-web /build /jellyfin/web

WORKDIR /jellyfin

EXPOSE 8096

ENTRYPOINT [ "/jellyfin/jellyfin" ]
CMD [ "--datadir", "/data", "--configdir", "/config", "--cachedir", "/cache", "--webdir", "/jellyfin/web" ]
