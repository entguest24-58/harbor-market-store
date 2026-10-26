#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with two placed orders" $LINENO
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product cxl 1000 10
PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PID" 1
cv_checkout "$TOKEN"
O1=$CV_ORDER_ID
cv_add_to_cart "$TOKEN" "$PID" 1
cv_checkout "$TOKEN"
O2=$CV_ORDER_ID

# When
cv_step When "the shopper cancels the first order and lists orders" $LINENO
cv_http POST "/orders/$O1/cancel" ""  -H "Authorization: Bearer $TOKEN"
CANCEL_STATUS=$CV_HTTP_STATUS
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the cancelled order remains listed as cancelled and the other stays placed" $LINENO
[ "$CANCEL_STATUS" = "200" ] || cv_fail "expected cancel 200 got $CANCEL_STATUS" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected list 200 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" = "2" ] || cv_fail "expected 2 orders got $(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" $LINENO
S1=$(jq -r --argjson o "$O1" '.orders[] | select(.id==$o) | .status' <<<"$CV_HTTP_BODY")
S2=$(jq -r --argjson o "$O2" '.orders[] | select(.id==$o) | .status' <<<"$CV_HTTP_BODY")
[ "$S1" = "cancelled" ] || cv_fail "expected order $O1 cancelled got '$S1'" $LINENO
[ "$S2" = "placed" ] || cv_fail "expected order $O2 placed got '$S2'" $LINENO
for o in "$O1" "$O2"; do
  AV=$(jq -r --argjson o "$o" --argjson p "$PID" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p) | .available' <<<"$CV_HTTP_BODY")
  [ "$AV" = "true" ] || cv_fail "expected in-stock product $PID available=true on order $o got '$AV'" $LINENO
done

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_list_reflects_canceled_orders_state"
