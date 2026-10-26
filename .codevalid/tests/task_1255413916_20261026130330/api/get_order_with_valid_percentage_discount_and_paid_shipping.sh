#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper who checked out a 4800-cent cart with a valid 20% code (discounted 3840 < 4000)" $LINENO
cv_register_user staff staff; STAFF_TOKEN=$CV_TOKEN
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; SHOP_ID=$CV_USER_ID
cv_seed_product 2400 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 2
CODE=$(cv_code_name GET)
cv_create_code "$STAFF_TOKEN" "$CODE" percentage 20 4000
cv_checkout "$SHOP_TOKEN" "$CODE"; OID=$CV_ORDER_ID

# When
cv_step When "the shopper fetches the order by id" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $SHOP_TOKEN"

# Then
cv_step Then "the order has subtotal 4800, discount 960, shipping 599, total 4439 and the code" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders/$OID got $CV_HTTP_STATUS" $LINENO
O=$(jq -c '.order' <<<"$CV_HTTP_BODY")
cv_jeq "$O" '.id' "$OID" "order.id" $LINENO
cv_jeq "$O" '.userId' "$SHOP_ID" "order.userId" $LINENO
cv_jeq "$O" '.status' placed "order.status" $LINENO
cv_jeq "$O" '.subtotalCents' 4800 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 960 "order.discountCents" $LINENO
cv_jeq "$O" '.shippingCents' 599 "order.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 4439 "order.totalCents" $LINENO
cv_jeq "$O" '.totalCents == (.subtotalCents - .discountCents + .shippingCents)' true "total = subtotal - discount + shipping" $LINENO
cv_jeq "$O" '.items | length' 1 "order.items length" $LINENO
cv_jeq "$O" '.items[0].quantity' 2 "items[0].quantity" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_order_with_valid_percentage_discount_and_paid_shipping"
