#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's discounted order that has been cancelled" $LINENO
cv_new_user shopper
TOKEN=$CV_TOKEN; USER_ID=$CV_USER_ID
cv_new_product item 2000 5
PID=$CV_PRODUCT_ID
cv_new_discount O fixed 300
CODE=$CV_DISCOUNT_CODE; DID=$CV_DISCOUNT_ID
cv_add_to_cart "$TOKEN" "$PID" 2
cv_checkout "$TOKEN" "$CODE"; OID=$CV_ORDER_ID
cv_http POST "/orders/$OID/cancel" "" 200 -H "Authorization: Bearer $TOKEN"

# When
cv_step When "the shopper opens the cancelled order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order shows cancelled status with historical items and discount, and code is reusable" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
B=$CV_HTTP_BODY
[ "$(jq -r '.order.id' <<<"$B")" = "$OID" ] || cv_fail "expected id $OID" $LINENO
[ "$(jq -r '.order.userId' <<<"$B")" = "$USER_ID" ] || cv_fail "expected userId $USER_ID" $LINENO
[ "$(jq -r '.order.status' <<<"$B")" = "cancelled" ] || cv_fail "expected cancelled got $(jq -r '.order.status' <<<"$B")" $LINENO
[ "$(jq -r '.order.items | length' <<<"$B")" = "1" ] || cv_fail "expected 1 item" $LINENO
[ "$(jq -r '.order.items[0] | "\(.productId)|\(.name)|\(.quantity)|\(.unitPriceCents)|\(.lineTotalCents)"' <<<"$B")" = "$PID|CV item $CV_SUFFIX|2|2000|4000" ] || cv_fail "expected item line preserved got $(jq -c '.order.items[0]' <<<"$B")" $LINENO
[ "$(jq -r '.order.discountCode' <<<"$B")" = "$CODE" ] || cv_fail "expected discountCode $CODE got $(jq -r '.order.discountCode' <<<"$B")" $LINENO
[ "$(jq -r '.order.discountCents' <<<"$B")" = "300" ] || cv_fail "expected discountCents 300" $LINENO
[ "$(jq -r '.order.subtotalCents' <<<"$B")" = "4000" ] || cv_fail "expected subtotal 4000" $LINENO
[ "$(jq -r '.order.totalCents' <<<"$B")" = "4299" ] || cv_fail "expected total 4299 got $(jq -r '.order.totalCents' <<<"$B")" $LINENO
[ "$(cv_code_holders "$DID")" = "0" ] || cv_fail "expected discount code not held by cancelled order" $LINENO
[ "$(jq -r '.order.items[0].available' <<<"$B")" = "true" ] || cv_fail "expected in-stock product $PID available=true got $(jq -r '.order.items[0].available' <<<"$B")" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 1
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected discount reuse checkout 201 got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:shopper_opens_canceled_order"
