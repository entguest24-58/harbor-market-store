#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with three orders (one cancelled, one with a removed product) and another shopper's order" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user other
OTHER=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN; USER_ID=$CV_USER_ID
cv_new_product a 1000 10
PA=$CV_PRODUCT_ID
cv_new_product b 1200 10
PB=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PA" 1
cv_checkout "$TOKEN"; O1=$CV_ORDER_ID
cv_add_to_cart "$TOKEN" "$PB" 1
cv_checkout "$TOKEN"; O2=$CV_ORDER_ID
cv_add_to_cart "$TOKEN" "$PA" 2
cv_checkout "$TOKEN"; O3=$CV_ORDER_ID
cv_add_to_cart "$OTHER" "$PA" 1
cv_checkout "$OTHER"; OX=$CV_ORDER_ID
cv_http POST "/orders/$O1/cancel" "" 200 -H "Authorization: Bearer $TOKEN"
cv_http DELETE "/products/$PB" "" 200 -H "Authorization: Bearer $STAFF"

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "only own orders, newest first, including cancelled and removed-product orders" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
IDS=$(jq -r '[.orders[].id] | join(",")' <<<"$CV_HTTP_BODY")
[ "$IDS" = "$O3,$O2,$O1" ] || cv_fail "expected ids $O3,$O2,$O1 got $IDS" $LINENO
[ "$(jq -r --argjson x "$OX" '[.orders[] | select(.id==$x)] | length' <<<"$CV_HTTP_BODY")" = "0" ] || cv_fail "expected other shopper's order excluded" $LINENO
[ "$(jq -r '[.orders[].userId] | unique | join(",")' <<<"$CV_HTTP_BODY")" = "$USER_ID" ] || cv_fail "expected all orders owned by $USER_ID" $LINENO
[ "$(jq -r --argjson o "$O1" '.orders[] | select(.id==$o) | .status' <<<"$CV_HTTP_BODY")" = "cancelled" ] || cv_fail "expected O1 cancelled" $LINENO
[ "$(jq -r --argjson o "$O3" '.orders[] | select(.id==$o) | .status' <<<"$CV_HTTP_BODY")" = "placed" ] || cv_fail "expected O3 placed" $LINENO
[ "$(jq -r --argjson o "$O2" --argjson p "$PB" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p) | .name' <<<"$CV_HTTP_BODY")" = "CV b $CV_SUFFIX" ] || cv_fail "expected removed product b visible in order $O2" $LINENO
C1=$(jq -r '.orders[0].createdAt' <<<"$CV_HTTP_BODY"); C3=$(jq -r '.orders[2].createdAt' <<<"$CV_HTTP_BODY")
[[ "$C1" > "$C3" || "$C1" == "$C3" ]] || cv_fail "expected createdAt descending got $C1 then $C3" $LINENO
AV=$(jq -r --argjson o "$O3" --argjson p "$PA" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p) | .available' <<<"$CV_HTTP_BODY")
[ "$AV" = "true" ] || cv_fail "expected in-stock product $PA available=true got '$AV'" $LINENO
AV=$(jq -r --argjson o "$O2" --argjson p "$PB" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p) | .available' <<<"$CV_HTTP_BODY")
[ "$AV" = "false" ] || cv_fail "expected removed product $PB available=false got '$AV'" $LINENO
cv_prereq "set product $PA stock to 0 and re-list" $LINENO
cv_sql "UPDATE products SET stock=0 WHERE id=$PA" >/dev/null || cv_fail "could not zero stock" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"
AV=$(jq -r --argjson o "$O3" --argjson p "$PA" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p) | .available' <<<"$CV_HTTP_BODY")
[ "$AV" = "false" ] || cv_fail "expected out-of-stock product $PA available=false got '$AV'" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_shopper_orders_newest_first"
