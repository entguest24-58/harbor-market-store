#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with one existing order and an empty cart" $LINENO
cv_register_user shopper; SHOP_TOKEN=$CV_TOKEN; UID_S=$CV_USER_ID
cv_seed_product 2000 5; PID=$CV_PRODUCT_ID
cv_add_to_cart "$SHOP_TOKEN" "$PID" 1
cv_checkout "$SHOP_TOKEN"; OID=$CV_ORDER_ID
cv_http GET /orders "" 200 -H "Authorization: Bearer $SHOP_TOKEN"
BEFORE=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
[ "$(jq 'length' <<<"$BEFORE")" = "1" ] || cv_fail "expected 1 order before got $BEFORE" $LINENO
[ "$(cv_cart_state "$UID_S")" = "" ] || cv_fail "expected empty cart" $LINENO

# When
cv_step When "the shopper attempts checkout with the empty cart and lists orders" $LINENO
cv_http POST /orders/checkout '{}' -H "Authorization: Bearer $SHOP_TOKEN"
CK_STATUS=$CV_HTTP_STATUS
cv_http GET /orders "" -H "Authorization: Bearer $SHOP_TOKEN"

# Then
cv_step Then "checkout refused and GET /orders shows only the unchanged existing order" $LINENO
[ "$CK_STATUS" = "400" ] || cv_fail "expected 400 from empty-cart checkout got $CK_STATUS" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing orders got $CV_HTTP_STATUS" $LINENO
AFTER=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
[ "$(jq 'length' <<<"$AFTER")" = "1" ] || cv_fail "expected 1 order after got $(jq 'length' <<<"$AFTER")" $LINENO
cv_jeq "$AFTER" '.[0].id' "$OID" "orders[0].id" $LINENO
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected orders unchanged $BEFORE got $AFTER" $LINENO
[ "$(cv_stock "$PID")" = "4" ] || cv_fail "expected stock 4 got $(cv_stock "$PID")" $LINENO

# Cleanup
cv_step Cleanup "remove user, order and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_no_order_for_empty_cart_checkout_attempt"
