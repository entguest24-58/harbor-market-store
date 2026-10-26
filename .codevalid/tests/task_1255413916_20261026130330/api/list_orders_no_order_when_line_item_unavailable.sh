#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with one prior order and a cart whose line has become unavailable" $LINENO
cv_register_user shopper; TOK=$CV_TOKEN; UID_=$CV_USER_ID
cv_seed_product 2000 5; P1=$CV_PRODUCT_ID
cv_add_to_cart "$TOK" "$P1" 1
cv_checkout "$TOK"; PRIOR_ID=$CV_ORDER_ID
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOK"
BEFORE=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
cv_seed_product 1500 3; P2=$CV_PRODUCT_ID
cv_add_to_cart "$TOK" "$P2" 2
cv_add_to_cart "$TOK" "$P1" 1
cv_sql "UPDATE products SET stock=1 WHERE id=$P2" >/dev/null || cv_fail "could not deplete stock of product $P2" $LINENO
STOCK_P1=$(cv_stock "$P1"); STOCK_P2=$(cv_stock "$P2")

# When
cv_step When "the shopper attempts checkout and then lists their orders" $LINENO
cv_http POST /orders/checkout '{}' -H "Authorization: Bearer $TOK"
CO_STATUS=$CV_HTTP_STATUS; CO_BODY=$CV_HTTP_BODY
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "checkout is refused, no new order appears, prior order intact, stock and cart unchanged" $LINENO
[ "$CO_STATUS" = "409" ] || cv_fail "expected 409 from checkout with unavailable line got $CO_STATUS: $CO_BODY" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 1 "orders count" $LINENO
cv_jeq "$LIST_BODY" '.orders[0].id' "$PRIOR_ID" "orders[0].id" $LINENO
AFTER=$(jq -c '.orders' <<<"$LIST_BODY")
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected prior orders unchanged got $AFTER (before $BEFORE)" $LINENO
[ "$(cv_stock "$P1")" = "$STOCK_P1" ] || cv_fail "expected stock of $P1 = $STOCK_P1 got $(cv_stock "$P1")" $LINENO
[ "$(cv_stock "$P2")" = "$STOCK_P2" ] || cv_fail "expected stock of $P2 = $STOCK_P2 got $(cv_stock "$P2")" $LINENO
CART=$(cv_cart_state "$UID_")
EXP_CART=$(printf '%s\n' "$P1:1" "$P2:2" | sort -t: -k1,1n | paste -sd, -)
[ "$CART" = "$EXP_CART" ] || cv_fail "expected cart $EXP_CART got $CART" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_no_order_when_line_item_unavailable"
