#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4783202215_20261026130330/api/_infra.sh

# Given
cv_step Given "a customer has a placed order and a staff user is logged in" $LINENO
cv_placed_order shipcust
OID=$CV_ORDER_ID
cv_register_user shipstaff staff
STAFF_TOKEN=$CV_TOKEN

# When
cv_step When "staff ships the placed order" $LINENO
cv_http POST "/orders/$OID/ship" "" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "response is 200 with status shipped and the order is shipped in the database" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
RID=$(jq -r '.order.id' <<<"$CV_HTTP_BODY")
RST=$(jq -r '.order.status' <<<"$CV_HTTP_BODY")
[ "$RID" = "$OID" ] || cv_fail "expected order.id $OID got $RID" $LINENO
[ "$RST" = "shipped" ] || cv_fail "expected order.status shipped got $RST" $LINENO
DBST=$(cv_order_status "$OID")
[ "$DBST" = "shipped" ] || cv_fail "expected db status shipped got $DBST" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $CV_CUST_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 reading order got $CV_HTTP_STATUS" $LINENO
GST=$(jq -r '.order.status' <<<"$CV_HTTP_BODY")
[ "$GST" = "shipped" ] || cv_fail "expected customer view status shipped got $GST" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:ship_placed_order_success"
