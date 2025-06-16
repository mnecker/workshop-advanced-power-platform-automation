#!/bin/bash

# Set Azure location
LOCATION="northeurope"

# Loop through users 1 to 100
for i in {1..100}; do
  rg="rgdev$i"
  user="dev$i@wpaine.onmicrosoft.com"

  echo "Creating resource group: $rg"
  az group create --name "$rg" --location "$LOCATION"

  echo "Assigning Contributor role to $user on $rg"
  az role assignment create \
    --assignee "$user" \
    --role "Contributor" \
    --scope "/subscriptions/69b0d561-ba59-42b4-ac23-6abfe7745ef4/resourceGroups/$rg"
done