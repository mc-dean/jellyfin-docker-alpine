FROM alpine:3 AS builder

RUN apk add bash icu-libs krb5-libs libgcc libintl libssl1.1 libstdc++ zlib git
# TODO not sure if this is necessary check!
RUN apk add libgdiplus --repository https://dl-3.alpinelinux.org/alpine/edge/testing/

WORKDIR /dotnet-build
# TODO work out how to parameterise this into a build arg
RUN wget https://download.visualstudio.microsoft.com/download/pr/21fdb75c-4eb5-476d-a8b8-1d096e4b7b14/c1f853410a58713cf5a56518ceeb87e8/dotnet-sdk-5.0.202-linux-musl-x64.tar.gz \
  && mkdir -p dotnet-sdk \
  && tar -xzf dotnet-sdk-5.0.202-linux-musl-x64.tar.gz -C dotnet-sdk \
  && rm dotnet-sdk-5.0.202-linux-musl-x64.tar.gz \
  && ln -s $( pwd )/dotnet-sdk/dotnet /usr/bin/dotnet

ARG JELLYFIN_VERSION=v10.7.2

WORKDIR /jellyfin

RUN git clone --branch ${JELLYFIN_VERSION} --depth 1 https://github.com/jellyfin/jellyfin.git . \
  && dotnet publish Jellyfin.Server --configuration Release --self-contained --runtime linux-musl-x64 --output dist/ "-p:DebugSymbols=false;DebugType=none;UseAppHost=true" \
  && mv ./dist /build \
  && rm -rf /jellyfin

FROM node:alpine3.10 AS builder-web

RUN apk add git

ARG JELLYFIN_VERSION=v10.7.2
ARG JELLYFIN_WEB_VERSION=v10.7.2

WORKDIR /jellyfin

RUN git clone --branch ${JELLYFIN_VERSION} --depth 1 https://github.com/jellyfin/jellyfin-web.git . \
  && yarn install \
  && yarn run build:production \
  && mv ./dist /build \
  && rm -rf /jellyfin

FROM alpine:3 AS runtime

RUN apk add libstdc++ icu-libs krb5-libs lttng-ust fontconfig ffmpeg

COPY --from=builder /build /jellyfin/bin
COPY --from=builder-web /build /jellyfin/bin/jellyfin-web

WORKDIR /jellyfin

HEALTHCHECK --interval=35s --timeout=4s CMD wget http://localhost:8096 || exit 1

EXPOSE 8096

ENTRYPOINT [ "/jellyfin/bin/jellyfin" ]
