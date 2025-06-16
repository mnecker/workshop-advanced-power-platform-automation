#!/bin/bash
#pac auth login --tenant wpaine.onmicrosoft.com
for i in {1..100}
do
  pac admin create \
  --name "Dev$i" \
  --type 'Developer' \
  --currency 'EUR' \
  --language 'English' \
  --region 'europe' \
  --async true \
  --user "dev$i@wpaine.onmicrosoft.com"
done