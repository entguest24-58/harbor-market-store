#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "two shoppers who each have placed an order" $LINENO
cv_new_product scoped 1200 10
PID=$CV_PRODUCT_ID
cv_new_user shopa
TOKEN_A=$CV_TOKEN; USER_A=$CV_USER_ID
cv_add_to_cart "$TOKEN_A" "$PID" 1
cv_checkout "$TOKEN_A"
OID_A=$CV_ORDER_ID
cv_new_user shopb
TOKEN_B=$CV_TOKEN
cv_add_to_cart "$TOKEN_B" "$PID" 2
cv_checkout "$TOKEN_B"
OID_B=$CV_ORDER_ID

# When
cv_step When "shopper A lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN_A"

# Then
cv_step Then "only shopper A's order is returned and B's order is not discoverable" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" = "1" ] || cv_fail "expected 1 order got $(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" $LINENO
[ "$(jq -r '.orders[0].id' <<<"$CV_HTTP_BODY")" = "$OID_A" ] || cv_fail "expected order $OID_A" $LINENO
OTHER=$(jq -r --argjson u "$USER_A" '[.orders[] | select(.userId != $u)] | length' <<<"$CV_HTTP_BODY")
[ "$OTHER" = "0" ] || cv_fail "expected no orders of other users got $OTHER" $LINENO
[ "$(jq -r --argjson o "$OID_B" '[.orders[] | select(.id==$o)] | length' <<<"$CV_HTTP_BODY")" = "0" ] || cv_fail "expected B's order $OID_B not listed" $LINENO
cv_http GET "/orders/$OID_B" "" -H "Authorization: Bearer $TOKEN_A"
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 opening B's order got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:orders_are_scoped_to_requesting_shopper"
