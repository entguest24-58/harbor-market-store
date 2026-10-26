#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's order with an in-stock, a removed and an out-of-stock product" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product instock 1000 10
PA=$CV_PRODUCT_ID
cv_new_product gone 800 10
PR=$CV_PRODUCT_ID
cv_new_product empty 600 2
PO=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PA" 1
cv_add_to_cart "$TOKEN" "$PR" 1
cv_add_to_cart "$TOKEN" "$PO" 2
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
cv_http DELETE "/products/$PR" "" 200 -H "Authorization: Bearer $STAFF"
[ "$(cv_stock "$PO")" = "0" ] || cv_fail "expected stock 0 for $PO got $(cv_stock "$PO")" $LINENO

# When
cv_step When "the shopper opens the order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "only the in-stock product line is available" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
B=$CV_HTTP_BODY
[ "$(jq -r '.order.items | length' <<<"$B")" = "3" ] || cv_fail "expected 3 lines got $(jq -r '.order.items | length' <<<"$B")" $LINENO
AA=$(jq -r --argjson p "$PA" '.order.items[] | select(.productId==$p) | .available' <<<"$B")
AR=$(jq -r --argjson p "$PR" '.order.items[] | select(.productId==$p) | .available' <<<"$B")
AO=$(jq -r --argjson p "$PO" '.order.items[] | select(.productId==$p) | .available' <<<"$B")
[ "$AA" = "true" ] || cv_fail "expected in-stock product available=true got '$AA'" $LINENO
[ "$AR" = "false" ] || cv_fail "expected removed product available=false got '$AR'" $LINENO
[ "$AO" = "false" ] || cv_fail "expected out-of-stock product available=false got '$AO'" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_lines_show_mixed_product_availability"
