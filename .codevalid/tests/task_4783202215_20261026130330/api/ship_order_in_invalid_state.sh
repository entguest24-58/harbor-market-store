#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4783202215_20261026130330/api/_infra.sh

# Given
cv_step Given "a customer's order has been cancelled and a staff user is logged in" $LINENO
cv_placed_order shipcust
OID=$CV_ORDER_ID
cv_prereq "cancel order $OID" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $CV_CUST_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 cancelling order got $CV_HTTP_STATUS" $LINENO
[ "$(cv_order_status "$OID")" = "cancelled" ] || cv_fail "expected order cancelled before ship" $LINENO
cv_register_user shipstaff staff
STAFF_TOKEN=$CV_TOKEN

# When
cv_step When "staff tries to ship the cancelled order" $LINENO
cv_http POST "/orders/$OID/ship" "" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "request is rejected with a business-rule error and the order stays cancelled" $LINENO
case "$CV_HTTP_STATUS" in 400|409|422) ;; *) cv_fail "expected 400/409/422 got $CV_HTTP_STATUS" $LINENO ;; esac
DBST=$(cv_order_status "$OID")
[ "$DBST" = "cancelled" ] || cv_fail "expected db status cancelled got $DBST" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:ship_order_in_invalid_state"
