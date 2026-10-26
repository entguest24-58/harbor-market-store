#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a logged-in shopper and an order id that does not exist" $LINENO
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN
MAXID=$(cv_sql "SELECT coalesce(max(id),0) FROM orders") || cv_fail "could not read max order id" $LINENO
_cv_is_int "$MAXID" || cv_fail "expected integer max order id got '$MAXID'" $LINENO
MISSING=$((MAXID + 1000000))

# When
cv_step When "the shopper fetches the non-existent order" $LINENO
cv_http GET "/orders/$MISSING" "" -H "Authorization: Bearer $SHOP_TOKEN"

# Then
cv_step Then "response is 404 and contains no order data" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 from GET /orders/$MISSING got $CV_HTTP_STATUS" $LINENO
HAS=$(jq -r 'if type=="object" then has("order") else false end' <<<"$CV_HTTP_BODY" 2>/dev/null || echo false)
[ "$HAS" = "false" ] || cv_fail "expected no order field in 404 body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "remove the user created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_nonexistent_order_id_returns_not_found"
