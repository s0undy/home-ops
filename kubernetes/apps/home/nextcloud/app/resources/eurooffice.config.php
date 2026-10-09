<?php
// Euro-Office connector (eurooffice app). The app falls back to these when the
// matching value is left empty in its admin settings, so keep those empty.
$CONFIG = array (
  'eurooffice' => array (
    // Browsers load the editors from here
    'DocumentServerUrl' => 'https://office.${SECRET_DOMAIN}/',
    // Nextcloud's own requests go straight to the service, not through Envoy
    'DocumentServerInternalUrl' => 'http://euro-office.home.svc.cluster.local/',
    // From euro-office-secret, shared with the document server
    'jwt_secret' => getenv('EUROOFFICE_JWT_SECRET'),
  ),
);
