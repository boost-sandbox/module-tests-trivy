#!/bin/bash

rm -rf gitleaks
git clone git@github.com:gitleaks/gitleaks.git
git -C gitleaks checkout v8.15.2
rm -rf gitleaks/.git

rm -rf osv-scanner
git clone git@github.com:google/osv-scanner.git
git -C osv-scanner checkout v1.0.2
rm -rf osv-scanner/.git

rm -rf rclone
git clone git@github.com:rclone/rclone.git
git -C rclone checkout v1.62.2
rm -rf rclone/.git
