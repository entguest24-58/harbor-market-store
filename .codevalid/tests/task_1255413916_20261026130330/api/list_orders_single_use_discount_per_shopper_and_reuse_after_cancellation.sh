#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper who already checked out once with a 10% code" $LINENO
cv_register_user staff staff; STAFF=$CV_TOKEN
cv_register_user shopper; TOK=$CV_TOKEN; UID_=$CV_USER_ID
cv_seed_product 2000 20; PID=$CV_PRODUCT_ID
CODE=$(cv_code_name ONE)
cv_create_code "$STAFF" "$CODE" percentage 10 0; CID=$CV_CODE_ID
cv_add_to_cart "$TOK" "$PID" 1
cv_checkout "$TOK" "$CODE"; FIRST_ID=$CV_ORDER_ID
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOK"
cv_jeq "$CV_HTTP_BODY" '.orders | length' 1 "orders after first checkout" $LINENO
cv_jeq "$CV_HTTP_BODY" '.orders[0].discountCode' "$CODE" "first order discountCode" $LINENO
BEFORE=$(jq -c '.orders' <<<"$CV_HTTP_BODY")
cv_add_to_cart "$TOK" "$PID" 1

# When
cv_step When "the shopper reuses the code, cancels the first order, then reuses the code again" $LINENO
cv_http POST /orders/checkout "$(jq -nc --arg c "$CODE" '{discountCode:$c}')" -H "Authorization: Bearer $TOK"
REUSE_STATUS=$CV_HTTP_STATUS; REUSE_BODY=$CV_HTTP_BODY
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
MID_STATUS=$CV_HTTP_STATUS; MID_BODY=$CV_HTTP_BODY
cv_http POST "/orders/$FIRST_ID/cancel" "" -H "Authorization: Bearer $TOK"
CANCEL_STATUS=$CV_HTTP_STATUS
cv_http POST /orders/checkout "$(jq -nc --arg c "$CODE" '{discountCode:$c}')" -H "Authorization: Bearer $TOK"
AGAIN_STATUS=$CV_HTTP_STATUS; AGAIN_BODY=$CV_HTTP_BODY
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "reuse is refused while order is active; after cancellation a new order uses the code" $LINENO
[ "$REUSE_STATUS" = "409" ] || cv_fail "expected 409 reusing code got $REUSE_STATUS: $REUSE_BODY" $LINENO
jq -e '.error | tostring | test("already been used"; "i")' <<<"$REUSE_BODY" >/dev/null || cv_fail "expected reason 'already been used' got $REUSE_BODY" $LINENO
[ "$MID_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $MID_STATUS" $LINENO
MID=$(jq -c '.orders' <<<"$MID_BODY")
[ "$MID" = "$BEFORE" ] || cv_fail "expected orders unchanged after refused reuse got $MID" $LINENO
[ "$CANCEL_STATUS" = "200" ] || cv_fail "expected 200 cancelling first order got $CANCEL_STATUS" $LINENO
[ "$AGAIN_STATUS" = "201" ] || cv_fail "expected 201 checking out with freed code got $AGAIN_STATUS: $AGAIN_BODY" $LINENO
NEW_ID=$(jq -r '.order.id' <<<"$AGAIN_BODY")
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
cv_jeq "$LIST_BODY" '.orders | length' 2 "orders count" $LINENO
F=$(jq -c --argjson id "$FIRST_ID" '.orders[] | select(.id==$id)' <<<"$LIST_BODY")
N=$(jq -c --argjson id "$NEW_ID" '.orders[] | select(.id==$id)' <<<"$LIST_BODY")
[ -n "$F" ] || cv_fail "expected first order $FIRST_ID in list got none" $LINENO
[ -n "$N" ] || cv_fail "expected new order $NEW_ID in list got none" $LINENO
cv_jeq "$F" '.status' cancelled "first order status" $LINENO
cv_jeq "$F" '.discountCode' "$CODE" "first order discountCode" $LINENO
cv_jeq "$N" '.status' placed "new order status" $LINENO
cv_jeq "$N" '.discountCode' "$CODE" "new order discountCode" $LINENO
cv_jeq "$N" '.subtotalCents' 2000 "new order subtotalCents" $LINENO
cv_jeq "$N" '.discountCents' 200 "new order discountCents" $LINENO
cv_jeq "$N" '.shippingCents' 599 "new order shippingCents" $LINENO
cv_jeq "$N" '.totalCents' 2399 "new order totalCents" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders, code and product created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_single_use_discount_per_shopper_and_reuse_after_cancellation"
