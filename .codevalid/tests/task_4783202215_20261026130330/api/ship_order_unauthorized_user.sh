#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4783202215_20261026130330/api/_infra.sh

# Given
cv_step Given "a customer has a placed order" $LINENO
cv_placed_order shipcust
OID=$CV_ORDER_ID

# When
cv_step When "the customer (non-staff) tries to ship the order" $LINENO
cv_http POST "/orders/$OID/ship" "" -H "Authorization: Bearer $CV_CUST_TOKEN"

# Then
cv_step Then "response is 403 and the order stays placed" $LINENO
[ "$CV_HTTP_STATUS" = "403" ] || cv_fail "expected 403 got $CV_HTTP_STATUS" $LINENO
DBST=$(cv_order_status "$OID")
[ "$DBST" = "placed" ] || cv_fail "expected db status placed got $DBST" $LINENO
cv_http POST "/orders/$OID/ship" ""
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 without token got $CV_HTTP_STATUS" $LINENO
DBST=$(cv_order_status "$OID")
[ "$DBST" = "placed" ] || cv_fail "expected db status placed after unauthenticated attempt got $DBST" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:ship_order_unauthorized_user"
