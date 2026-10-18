#!/bin/sh
# before-starting hook: point the whiteboard app at its collaboration server.
# The app only reads these from its app config (database), not config.php, so
# reapply them from env on every start to keep them in sync with SOPS.
# A failing hook aborts the entrypoint and Nextcloud with it, so only warn.
if [ -z "$WHITEBOARD_URL" ] || [ -z "$WHITEBOARD_JWT_SECRET" ]; then
  echo "WARNING: whiteboard: WHITEBOARD_URL or WHITEBOARD_JWT_SECRET is empty, skipping" >&2
  exit 0
fi
occ() { php /var/www/html/occ "$@" >/dev/null; }
# No --type on the secret: occ compares it against the stored type including
# the sensitive flag, so it always differs and occ waits for a confirmation
occ config:app:set whiteboard collabBackendUrl --type=string --value="$WHITEBOARD_URL" \
  && occ config:app:set whiteboard jwt_secret_key --sensitive --value="$WHITEBOARD_JWT_SECRET" \
  && echo "whiteboard: collaboration server set to $WHITEBOARD_URL" \
  || echo "WARNING: whiteboard: could not set app config" >&2
exit 0
