# Base Dreadnought image
FROM delivery.instana.io/int-docker-base-images-local/base-images/init-5.1-builder:dn-latest

# Token for authenticating access to asset
ARG PAT_TOKEN

# URL to GHE for asset download
ENV DOWNLOAD_URL='https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/assets/'

# Retrieve the asset id for the specific version of the linux installer
RUN echo $(curl -s -H "Authorization: token ${PAT_TOKEN}" 'https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/latest' | \
grep -B 5 "instana-collector-installer-v" | \
sed -n 's/.*"id":\s*\([0-9]*\),*/\1/p' | \
tr -d ' ' | \
tr -d ',') >> /asset_id.txt

# Get version
RUN echo $(curl -s -H "Authorization: token ${PAT_TOKEN}"'https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/latest' | \
grep "instana-collector-installer-v" | \
grep "name" | \
sed -n 's/.*\(v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p') >> /version.txt

# Download the versioned installer for linux, make it executable and run installer
RUN VERSIONED_ASSET_ID=$(cat /asset_id.txt) && VERSION=$(cat /version.txt) && curl -L \
  -H "Accept: application/octet-stream" \
  -H "Authorization: token ${PAT_TOKEN}"  \
  "${DOWNLOAD_URL}${VERSIONED_ASSET_ID}" -o instana_otelcol_setup_${VERSION}.sh \
  && chmod +x instana_otelcol_setup_${VERSION}.sh \
  && ./instana_otelcol_setup_${VERSION}.sh -s -e localhost:0000 -a tempkey