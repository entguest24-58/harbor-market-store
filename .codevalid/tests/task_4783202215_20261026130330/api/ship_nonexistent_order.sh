#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4783202215_20261026130330/api/_infra.sh

# Given
cv_step Given "a staff user and an order id that does not exist" $LINENO
cv_register_user shipstaff staff
STAFF_TOKEN=$CV_TOKEN
MAXID=$(cv_sql "SELECT COALESCE(MAX(id),0) FROM orders") || cv_fail "could not read max order id" $LINENO
MISSING=$((MAXID + 900000))
SHIPPED_BEFORE=$(cv_sql "SELECT count(*) FROM orders WHERE status='shipped'") || cv_fail "could not count shipped orders" $LINENO

# When
cv_step When "staff ships the non-existent order" $LINENO
cv_http POST "/orders/$MISSING/ship" "" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "response is 404 and no order row exists or was changed" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
CNT=$(cv_sql "SELECT count(*) FROM orders WHERE id=$MISSING")
[ "$CNT" = "0" ] || cv_fail "expected no order with id $MISSING got $CNT" $LINENO
SHIPPED_AFTER=$(cv_sql "SELECT count(*) FROM orders WHERE status='shipped' AND id >= $MISSING")
[ "$SHIPPED_AFTER" = "0" ] || cv_fail "expected no shipped order created got $SHIPPED_AFTER" $LINENO
echo "shipped orders before: $SHIPPED_BEFORE"

# Cleanup
cv_step Cleanup "remove the staff user" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:ship_nonexistent_order"
