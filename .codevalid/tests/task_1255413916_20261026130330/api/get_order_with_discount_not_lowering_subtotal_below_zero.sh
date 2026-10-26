#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper checked out a 1500-cent cart with a fixed 5000-cent code" $LINENO
cv_register_user staff staff; STAFF_TOKEN=$CV_TOKEN
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN
cv_seed_product 1500 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 1
CODE=$(cv_code_name BIG)
cv_create_code "$STAFF_TOKEN" "$CODE" fixed 5000 0
cv_checkout "$SHOP_TOKEN" "$CODE"; OID=$CV_ORDER_ID

# When
cv_step When "the shopper fetches the order by id" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $SHOP_TOKEN"

# Then
cv_step Then "discount is capped at 1500, discounted subtotal 0, shipping 599, total 599" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders/$OID got $CV_HTTP_STATUS" $LINENO
O=$(jq -c '.order' <<<"$CV_HTTP_BODY")
cv_jeq "$O" '.id' "$OID" "order.id" $LINENO
cv_jeq "$O" '.subtotalCents' 1500 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 1500 "order.discountCents (capped)" $LINENO
cv_jeq "$O" '(.subtotalCents - .discountCents) >= 0' true "discounted subtotal non-negative" $LINENO
cv_jeq "$O" '.shippingCents' 599 "order.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 599 "order.totalCents" $LINENO
cv_jeq "$O" '.totalCents >= 0' true "total non-negative" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_order_with_discount_not_lowering_subtotal_below_zero"
