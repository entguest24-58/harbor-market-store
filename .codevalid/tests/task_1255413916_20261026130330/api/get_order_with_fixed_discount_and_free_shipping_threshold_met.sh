#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper checked out a 6000-cent cart with a fixed 500-cent code (discounted 5500 >= 4000)" $LINENO
cv_register_user staff staff; STAFF_TOKEN=$CV_TOKEN
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; SHOP_ID=$CV_USER_ID
cv_seed_product 3000 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 2
CODE=$(cv_code_name FIX)
cv_create_code "$STAFF_TOKEN" "$CODE" fixed 500 0
cv_checkout "$SHOP_TOKEN" "$CODE"; OID=$CV_ORDER_ID

# When
cv_step When "the shopper fetches the order by id" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $SHOP_TOKEN"

# Then
cv_step Then "order shows subtotal 6000, discount 500, shipping 0, total 5500 and the code" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders/$OID got $CV_HTTP_STATUS" $LINENO
O=$(jq -c '.order' <<<"$CV_HTTP_BODY")
cv_jeq "$O" '.id' "$OID" "order.id" $LINENO
cv_jeq "$O" '.userId' "$SHOP_ID" "order.userId" $LINENO
cv_jeq "$O" '.status' placed "order.status" $LINENO
cv_jeq "$O" '.subtotalCents' 6000 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 500 "order.discountCents" $LINENO
cv_jeq "$O" '.shippingCents' 0 "order.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 5500 "order.totalCents" $LINENO
cv_jeq "$O" '.items | length' 1 "order.items length" $LINENO
cv_jeq "$O" '.items[0].productId' "$PID" "items[0].productId" $LINENO
cv_jeq "$O" '.items[0].quantity' 2 "items[0].quantity" $LINENO
cv_jeq "$O" '.items[0].lineTotalCents' 6000 "items[0].lineTotalCents" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_order_with_fixed_discount_and_free_shipping_threshold_met"
