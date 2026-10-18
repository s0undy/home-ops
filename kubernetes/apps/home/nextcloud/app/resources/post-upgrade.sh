#!/bin/sh
# post-upgrade hook: the follow-up steps `occ upgrade` leaves to the admin.
# Only runs after the entrypoint upgraded Nextcloud, not on every start, and
# php-fpm waits for it, so it counts against the startup probe.
# A failing hook aborts the entrypoint and Nextcloud with it, so only warn.
occ() { php /var/www/html/occ --no-interaction "$@"; }
for cmd in \
  "db:add-missing-indices" \
  "db:add-missing-columns" \
  "db:add-missing-primary-keys" \
  "maintenance:repair --include-expensive"; do
  # shellcheck disable=SC2086 # cmd holds a command plus its options
  occ $cmd || echo "WARNING: post-upgrade: occ $cmd failed" >&2
done
exit 0
