#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with a 6000-cent cart who checked out with a valid 20% code" $LINENO
cv_register_user staff staff; STAFF_TOKEN=$CV_TOKEN
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; SHOP_ID=$CV_USER_ID
cv_seed_product 3000 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 2
CODE=$(cv_code_name LST)
cv_create_code "$STAFF_TOKEN" "$CODE" percentage 20 5000
cv_checkout "$SHOP_TOKEN" "$CODE"; OID=$CV_ORDER_ID

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $SHOP_TOKEN"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "the discounted order appears with correct totals, stock is reserved and the cart is empty" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 1 "orders count" $LINENO
O=$(jq -c --argjson id "$OID" '.orders[] | select(.id==$id)' <<<"$LIST_BODY")
[ -n "$O" ] || cv_fail "expected order $OID in list got none" $LINENO
cv_jeq "$O" '.userId' "$SHOP_ID" "order.userId" $LINENO
cv_jeq "$O" '.status' placed "order.status" $LINENO
cv_jeq "$O" '.subtotalCents' 6000 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 1200 "order.discountCents" $LINENO
cv_jeq "$O" '.shippingCents' 0 "order.shippingCents (4800 >= 4000 threshold)" $LINENO
cv_jeq "$O" '.totalCents' 4800 "order.totalCents" $LINENO
cv_jeq "$O" '.items | length' 1 "order.items length" $LINENO
cv_jeq "$O" '.items[0].productId' "$PID" "items[0].productId" $LINENO
cv_jeq "$O" '.items[0].quantity' 2 "items[0].quantity" $LINENO
cv_jeq "$O" '.items[0].lineTotalCents' 6000 "items[0].lineTotalCents" $LINENO
STOCK=$(cv_sql "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "8" ] || cv_fail "expected stock 8 after checkout got $STOCK" $LINENO
cv_http GET /cart "" -H "Authorization: Bearer $SHOP_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /cart got $CV_HTTP_STATUS" $LINENO
cv_jeq "$CV_HTTP_BODY" '.cart.lines | length' 0 "cart lines after checkout" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_successful_checkout_with_valid_discount"
