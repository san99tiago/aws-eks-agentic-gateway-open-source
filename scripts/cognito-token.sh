#!/usr/bin/env bash
# Prints a Cognito ACCESS token for the demo user (santigrc@amazon.com). Export COGNITO_DEMO_PASSWORD to override.
source "$(dirname "$0")/_common.sh"
cognito_access_token
