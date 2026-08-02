#!/bin/sh
set -euo pipefail

SRC_DIR="${SRCROOT}/MAMONAKU/Config/Firebase"

if [ "${CONFIGURATION}" = "Debug" ]; then
  SOURCE="${SRC_DIR}/GoogleService-Info-STG.plist"
  ENV_NAME="STG"
else
  SOURCE="${SRC_DIR}/GoogleService-Info-PROD.plist"
  ENV_NAME="PROD"
fi

if [ ! -f "${SOURCE}" ]; then
  echo "error: Missing Firebase plist: ${SOURCE}" >&2
  exit 1
fi

# 参照用にソースツリーへも同期（ターゲット Resources には含めない）
cp "${SOURCE}" "${SRCROOT}/MAMONAKU/GoogleService-Info.plist"

# アプリバンドルへ配置（membership から除外済みのためスクリプトが唯一の供給源）
DEST_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "${DEST_DIR}"
cp "${SOURCE}" "${DEST_DIR}/GoogleService-Info.plist"

echo "Copied GoogleService-Info (${ENV_NAME}) for ${CONFIGURATION}"
