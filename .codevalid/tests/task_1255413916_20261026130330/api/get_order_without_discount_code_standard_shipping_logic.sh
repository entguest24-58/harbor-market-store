#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper checked out a 2000-cent cart (paid shipping) and a 5000-cent cart (free shipping) without codes" $LINENO
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; SHOP_ID=$CV_USER_ID
cv_seed_product 2000 10; P1=$CV_PRODUCT_ID
cv_seed_product 2500 10; P2=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$P1" 1
cv_checkout "$SHOP_TOKEN"; OID1=$CV_ORDER_ID
cv_add_to_cart "$SHOP_TOKEN" "$P2" 2
cv_checkout "$SHOP_TOKEN"; OID2=$CV_ORDER_ID

# When
cv_step When "the shopper fetches both orders by id" $LINENO
cv_http GET "/orders/$OID1" "" -H "Authorization: Bearer $SHOP_TOKEN"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http GET "/orders/$OID2" "" -H "Authorization: Bearer $SHOP_TOKEN"
S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY

# Then
cv_step Then "no code, zero discount, shipping by subtotal, total = subtotal + shipping" $LINENO
[ "$S1" = "200" ] || cv_fail "expected 200 from GET /orders/$OID1 got $S1" $LINENO
[ "$S2" = "200" ] || cv_fail "expected 200 from GET /orders/$OID2 got $S2" $LINENO
O=$(jq -c '.order' <<<"$B1")
cv_jeq "$O" '.id' "$OID1" "order1.id" $LINENO
cv_jeq "$O" '.userId' "$SHOP_ID" "order1.userId" $LINENO
cv_jeq "$O" '.status' placed "order1.status" $LINENO
cv_jeq "$O" '.discountCode' null "order1.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 0 "order1.discountCents" $LINENO
cv_jeq "$O" '.subtotalCents' 2000 "order1.subtotalCents" $LINENO
cv_jeq "$O" '.shippingCents' 599 "order1.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 2599 "order1.totalCents" $LINENO
O=$(jq -c '.order' <<<"$B2")
cv_jeq "$O" '.id' "$OID2" "order2.id" $LINENO
cv_jeq "$O" '.discountCode' null "order2.discountCode" $LINENO
cv_jeq "$O" '.discountCents' 0 "order2.discountCents" $LINENO
cv_jeq "$O" '.subtotalCents' 5000 "order2.subtotalCents" $LINENO
cv_jeq "$O" '.shippingCents' 0 "order2.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 5000 "order2.totalCents" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders and products created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:get_order_without_discount_code_standard_shipping_logic"
