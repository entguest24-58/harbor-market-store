#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4783202215_20261026130330/api/_infra.sh

# Given
cv_step Given "a customer's order has already been shipped by staff" $LINENO
cv_placed_order shipcust
OID=$CV_ORDER_ID
cv_register_user shipstaff staff
STAFF_TOKEN=$CV_TOKEN
cv_prereq "ship order $OID once" $LINENO
cv_http POST "/orders/$OID/ship" "" -H "Authorization: Bearer $STAFF_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 on first ship got $CV_HTTP_STATUS" $LINENO
[ "$(cv_order_status "$OID")" = "shipped" ] || cv_fail "expected order shipped after first ship" $LINENO
UPDATED_BEFORE=$(cv_sql "SELECT updated_at FROM orders WHERE id=$OID")

# When
cv_step When "staff ships the same order again" $LINENO
cv_http POST "/orders/$OID/ship" "" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "request is rejected or a no-op and the order remains shipped" $LINENO
case "$CV_HTTP_STATUS" in
  400|409|422) ;;
  200)
    RST=$(jq -r '.order.status' <<<"$CV_HTTP_BODY")
    [ "$RST" = "shipped" ] || cv_fail "expected no-op response status shipped got $RST" $LINENO
    ;;
  *) cv_fail "expected 409 (or 400/422, or 200 no-op) got $CV_HTTP_STATUS" $LINENO ;;
esac
DBST=$(cv_order_status "$OID")
[ "$DBST" = "shipped" ] || cv_fail "expected db status shipped got $DBST" $LINENO
UPDATED_AFTER=$(cv_sql "SELECT updated_at FROM orders WHERE id=$OID")
[ "$UPDATED_AFTER" = "$UPDATED_BEFORE" ] || cv_fail "expected order not modified again (updated_at $UPDATED_BEFORE) got $UPDATED_AFTER" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:ship_already_shipped_order"
