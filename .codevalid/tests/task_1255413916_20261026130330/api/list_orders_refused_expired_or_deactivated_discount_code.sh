#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with a prior order, a 3000-cent cart, an expired code and a deactivated code" $LINENO
cv_register_user staff staff; STAFF=$CV_TOKEN
cv_register_user shopper; TOK=$CV_TOKEN; UID_=$CV_USER_ID
cv_seed_product 1000 20; PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOK" "$PID" 1
cv_checkout "$TOK"; PRIOR_ID=$CV_ORDER_ID
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOK"
BEFORE=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
EXP_CODE=$(cv_code_name EXP)
cv_seed_expired_code "$EXP_CODE" percentage 10 0; EXP_ID=$CV_CODE_ID
DEA_CODE=$(cv_code_name DEA)
cv_create_code "$STAFF" "$DEA_CODE" fixed 500 0; DEA_ID=$CV_CODE_ID
cv_prereq "deactivate code $DEA_CODE" $LINENO
cv_http POST "/discount-codes/$DEA_ID/deactivate" "" 200 -H "Authorization: Bearer $STAFF"
cv_add_to_cart "$TOK" "$PID" 3
STOCK=$(cv_stock "$PID")

# When
cv_step When "the shopper checks out with each unusable code and then lists orders" $LINENO
cv_http POST /orders/checkout "$(jq -nc --arg c "$EXP_CODE" '{discountCode:$c}')" -H "Authorization: Bearer $TOK"
EXP_STATUS=$CV_HTTP_STATUS; EXP_BODY=$CV_HTTP_BODY
cv_http POST /orders/checkout "$(jq -nc --arg c "$DEA_CODE" '{discountCode:$c}')" -H "Authorization: Bearer $TOK"
DEA_STATUS=$CV_HTTP_STATUS; DEA_BODY=$CV_HTTP_BODY
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "both checkouts are refused with a reason and GET /orders shows no new order" $LINENO
[ "$EXP_STATUS" = "400" ] || cv_fail "expected 400 from checkout with expired code got $EXP_STATUS: $EXP_BODY" $LINENO
jq -e '.error | tostring | test("expired"; "i")' <<<"$EXP_BODY" >/dev/null || cv_fail "expected reason mentioning expired got $EXP_BODY" $LINENO
[ "$DEA_STATUS" = "400" ] || cv_fail "expected 400 from checkout with deactivated code got $DEA_STATUS: $DEA_BODY" $LINENO
jq -e '.error | tostring | test("active"; "i")' <<<"$DEA_BODY" >/dev/null || cv_fail "expected reason mentioning not active got $DEA_BODY" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 1 "orders count" $LINENO
cv_jeq "$LIST_BODY" '.orders[0].id' "$PRIOR_ID" "orders[0].id" $LINENO
cv_jeq "$LIST_BODY" '[.orders[] | select(.discountCode != null)] | length' 0 "orders with a discount code" $LINENO
AFTER=$(jq -c '.orders' <<<"$LIST_BODY")
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected prior orders unchanged got $AFTER" $LINENO
[ "$(cv_code_uses "$EXP_ID")" = "0" ] || cv_fail "expected expired code unused got $(cv_code_uses "$EXP_ID")" $LINENO
[ "$(cv_code_uses "$DEA_ID")" = "0" ] || cv_fail "expected deactivated code unused got $(cv_code_uses "$DEA_ID")" $LINENO
[ "$(cv_stock "$PID")" = "$STOCK" ] || cv_fail "expected stock $STOCK got $(cv_stock "$PID")" $LINENO
[ "$(cv_cart_state "$UID_")" = "$PID:3" ] || cv_fail "expected cart $PID:3 got $(cv_cart_state "$UID_")" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, codes and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_refused_expired_or_deactivated_discount_code"
