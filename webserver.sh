#!/bin/bash
set -euxo pipefail
dnf install -y httpd
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>BBE Sandbox</title></head>
<body><h1>Hello BBE_Sandbox</h1></body></html>
HTML
systemctl enable --now httpd
