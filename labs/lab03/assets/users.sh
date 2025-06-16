#!/bin/bash

# Set the domain
DOMAIN="wpaine.onmicrosoft.com"

# Replace this with actual Power Apps for Developer SKU ID from your tenant
SKU_ID="5b631642-bd26-49fe-bd20-1daaa972ef80"

# Default password (change it later)
DEFAULT_PASSWORD="hello42@EPPC"

for i in {2..100}
do
  UPN="dev${i}@${DOMAIN}"
  DISPLAY_NAME="Mighty Developer ${i}"

  echo "Creating user $UPN"

  az ad user create \
    --display-name "$DISPLAY_NAME" \
    --user-principal-name "$UPN" \
    --password "$DEFAULT_PASSWORD" \
    --force-change-password-next-sign-in false \
    --mail-nickname "dev${i}"

done