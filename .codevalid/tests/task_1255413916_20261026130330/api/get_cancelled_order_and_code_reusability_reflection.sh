#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper checked out 4000 cents with a 10% code and cancelled the order" $LINENO
cv_register_user staff staff; STAFF_TOKEN=$CV_TOKEN
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; SHOP_ID=$CV_USER_ID
cv_seed_product 2000 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 2
CODE=$(cv_code_name CAN)
cv_create_code "$STAFF_TOKEN" "$CODE" percentage 10 0; CODE_ID=$CV_CODE_ID
cv_checkout "$SHOP_TOKEN" "$CODE"; OID=$CV_ORDER_ID
cv_prereq "cancel order $OID" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $SHOP_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 cancelling order got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the shopper fetches the cancelled order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $SHOP_TOKEN"
GS=$CV_HTTP_STATUS; GB=$CV_HTTP_BODY

# Then
cv_step Then "order is cancelled with original pricing and the code can be applied again" $LINENO
[ "$GS" = "200" ] || cv_fail "expected 200 from GET /orders/$OID got $GS" $LINENO
O=$(jq -c '.order' <<<"$GB")
cv_jeq "$O" '.id' "$OID" "order.id" $LINENO
cv_jeq "$O" '.userId' "$SHOP_ID" "order.userId" $LINENO
cv_jeq "$O" '.status' cancelled "order.status" $LINENO
cv_jeq "$O" '.subtotalCents' 4000 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 400 "order.discountCents" $LINENO
cv_jeq "$O" '.shippingCents' 599 "order.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 4199 "order.totalCents" $LINENO
HOLD=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id=$CODE_ID AND user_id=$SHOP_ID AND status <> 'cancelled'")
[ "$HOLD" = "0" ] || cv_fail "expected 0 active orders holding the code got $HOLD" $LINENO
cv_add_to_cart "$SHOP_TOKEN" "$PID" 2
cv_http POST /orders/checkout "$(jq -nc --arg c "$CODE" '{discountCode:$c}')" -H "Authorization: Bearer $SHOP_TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 reusing freed code got $CV_HTTP_STATUS" $LINENO
cv_jeq "$CV_HTTP_BODY" '.order.discountCents' 400 "reused order.discountCents" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $SHOP_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 re-fetching cancelled order got $CV_HTTP_STATUS" $LINENO
cv_jeq "$CV_HTTP_BODY" '.order.status' cancelled "original order still cancelled" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_cancelled_order_and_code_reusability_reflection"
