#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with a prior order and a 3000-cent cart, plus a code requiring 5000 cents" $LINENO
cv_register_user staff staff; STAFF=$CV_TOKEN
cv_register_user shopper; TOK=$CV_TOKEN; UID_=$CV_USER_ID
cv_seed_product 1000 10; PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOK" "$PID" 1
cv_checkout "$TOK"; PRIOR_ID=$CV_ORDER_ID
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOK"
BEFORE=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
CODE=$(cv_code_name MIN)
cv_create_code "$STAFF" "$CODE" percentage 10 5000; CID=$CV_CODE_ID
cv_add_to_cart "$TOK" "$PID" 3
STOCK=$(cv_stock "$PID")

# When
cv_step When "the shopper checks out with the code and lists orders" $LINENO
cv_http POST /orders/checkout "$(jq -nc --arg c "$CODE" '{discountCode:$c}')" -H "Authorization: Bearer $TOK"
CO_STATUS=$CV_HTTP_STATUS; CO_BODY=$CV_HTTP_BODY
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "checkout is refused for minimum subtotal, no order uses the code, prior orders unchanged" $LINENO
[ "$CO_STATUS" = "400" ] || cv_fail "expected 400 from checkout below minimum got $CO_STATUS: $CO_BODY" $LINENO
jq -e '.error | tostring | test("subtotal"; "i")' <<<"$CO_BODY" >/dev/null || cv_fail "expected refusal reason mentioning minimum subtotal got $CO_BODY" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 1 "orders count" $LINENO
cv_jeq "$LIST_BODY" '.orders[0].id' "$PRIOR_ID" "orders[0].id" $LINENO
N=$(jq --arg c "$CODE" '[.orders[] | select((.discountCode // "") | ascii_downcase == ($c | ascii_downcase))] | length' <<<"$LIST_BODY")
[ "$N" = "0" ] || cv_fail "expected 0 orders using code $CODE got $N" $LINENO
AFTER=$(jq -c '.orders' <<<"$LIST_BODY")
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected prior orders unchanged got $AFTER" $LINENO
[ "$(cv_code_uses "$CID")" = "0" ] || cv_fail "expected 0 orders referencing code got $(cv_code_uses "$CID")" $LINENO
[ "$(cv_stock "$PID")" = "$STOCK" ] || cv_fail "expected stock $STOCK got $(cv_stock "$PID")" $LINENO
[ "$(cv_cart_state "$UID_")" = "$PID:3" ] || cv_fail "expected cart $PID:3 got $(cv_cart_state "$UID_")" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_refused_discount_due_to_minimum_subtotal"
