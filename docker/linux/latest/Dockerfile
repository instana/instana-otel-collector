# Base Dreadnought image
FROM delivery.instana.io/int-docker-base-images-local/base-images/init-5.1-builder:dn-latest

# Token for authenticating access to asset
ARG PAT_TOKEN

# URL to GHE for asset download
ENV DOWNLOAD_URL='https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/assets/'

# Retrieve the asset id for the latest version of the linux installer and save it to a temp file
RUN echo $(curl -s -H "Authorization: token ${PAT_TOKEN}" 'https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/latest' | \
grep -B 5 "instana-collector-installer-latest.sh" | \
sed -n 's/.*"id":\s*\([0-9]*\),*/\1/p' | \
tr -d ' ' | \
tr -d ',') >> /asset_id.txt

# Download the latest version of the linux installer, make it executable and run installer
RUN LATEST_ASSET_ID=$(cat /asset_id.txt) && curl -L \
  -H "Accept: application/octet-stream" \
  -H "Authorization: token ${PAT_TOKEN}"  \
  "${DOWNLOAD_URL}${LATEST_ASSET_ID}" -o instana_otelcol_setup_latest.sh \
  && chmod +x instana_otelcol_setup_latest.sh \
  && ./instana_otelcol_setup_latest.sh -s -e localhost:0000 -a tempkey

