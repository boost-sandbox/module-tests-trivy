#!/bin/bash

repos=(
  "gitleaks git@github.com:gitleaks/gitleaks.git v8.15.2"
  "osv-scanner git@github.com:google/osv-scanner.git main"
  "rclone git@github.com:rclone/rclone.git v1.65.2"
  "kubeaudit git@github.com:/Shopify/kubeaudit v0.18.0"
)

for repo in "${repos[@]}"; do
  read -r name url version <<<"$repo"
  
  rm -rf "$name"
  git clone "$url" "$name"
  git -C "$name" checkout "$version"
  rm -rf "$name/.git"
done
