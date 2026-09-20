#!/bin/zsh
# 本机出 Android 包：./scripts/build-android.sh [arm64|universal]，产物在 dist/。
# 环境由 scripts/setup-android-env.sh 准备。Gradle 不认 shell 的代理变量，这里按 HTTPS_PROXY（默认本机 127.0.0.1:7890）给 JVM；
# Go 模块用离线缓存（setup 已预热）。
set -e
cd "$(dirname "$0")/.."
SDK=$HOME/Library/Android/sdk
export ANDROID_HOME=$SDK ANDROID_NDK=$SDK/ndk/28.2.13676358 JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH=$HOME/.local/flutter/bin:$HOME/.pub-cache/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/.cargo/bin:$PATH
export GOPROXY=off GOFLAGS=-mod=mod
PROXY=${HTTPS_PROXY:-${https_proxy:-http://127.0.0.1:7890}}
PROXY_HOST=$(echo "$PROXY" | sed -E 's#^[a-z0-9]+://##; s#/.*##; s#:.*##'); PROXY_PORT=$(echo "$PROXY" | sed -E 's#.*:([0-9]+)/?$#\1#')
if nc -z "$PROXY_HOST" "$PROXY_PORT" 2>/dev/null; then
  export JAVA_TOOL_OPTIONS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts=localhost|127.0.0.1"
fi
dart setup.dart android --arch "${1:-arm64}" --env stable
ls -la dist/*.apk
