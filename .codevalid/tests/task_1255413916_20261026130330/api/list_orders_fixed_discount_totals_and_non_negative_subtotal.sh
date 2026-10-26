#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper who checked out with a 5000-cent fixed code on a 1200-cent cart" $LINENO
cv_register_user staff staff; STAFF=$CV_TOKEN
cv_register_user shopper; TOK=$CV_TOKEN
cv_seed_product 1200 10; PID=$CV_PRODUCT_ID
CODE=$(cv_code_name FIX)
cv_create_code "$STAFF" "$CODE" fixed 5000 0
cv_add_to_cart "$TOK" "$PID" 1
cv_checkout "$TOK" "$CODE"; OID=$CV_ORDER_ID

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "the order shows subtotal 1200, discount 1200, shipping 599, total = subtotal - discount + shipping" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 1 "orders count" $LINENO
O=$(jq -c --argjson id "$OID" '.orders[] | select(.id==$id)' <<<"$LIST_BODY")
[ -n "$O" ] || cv_fail "expected order $OID in list got none" $LINENO
cv_jeq "$O" '.status' placed "order.status" $LINENO
cv_jeq "$O" '.discountCode' "$CODE" "order.discountCode" $LINENO
cv_jeq "$O" '.subtotalCents' 1200 "order.subtotalCents" $LINENO
cv_jeq "$O" '.discountCents' 1200 "order.discountCents" $LINENO
cv_jeq "$O" '.shippingCents' 599 "order.shippingCents" $LINENO
cv_jeq "$O" '.totalCents' 599 "order.totalCents" $LINENO
cv_jeq "$O" '(.subtotalCents - .discountCents) >= 0' true "subtotal after discount non-negative" $LINENO
cv_jeq "$O" '.totalCents == (.subtotalCents - .discountCents + .shippingCents)' true "total = subtotal - discount + shipping" $LINENO
cv_jeq "$O" '[.items[].lineTotalCents] | add' 1200 "sum of item line totals" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_fixed_discount_totals_and_non_negative_subtotal"
