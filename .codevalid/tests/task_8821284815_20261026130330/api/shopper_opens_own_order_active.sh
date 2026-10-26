#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's placed order with two products, one later removed from the catalog" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN; USER_ID=$CV_USER_ID
cv_new_product keep 1000 5
PA=$CV_PRODUCT_ID
cv_new_product gone 700 5
PB=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PA" 1
cv_add_to_cart "$TOKEN" "$PB" 3
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
cv_http DELETE "/products/$PB" "" 200 -H "Authorization: Bearer $STAFF"

# When
cv_step When "the shopper opens the order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order details with all line items and metadata are returned" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
B=$CV_HTTP_BODY
[ "$(jq -r '.order.id' <<<"$B")" = "$OID" ] || cv_fail "expected id $OID" $LINENO
[ "$(jq -r '.order.userId' <<<"$B")" = "$USER_ID" ] || cv_fail "expected userId $USER_ID" $LINENO
[ "$(jq -r '.order.status' <<<"$B")" = "placed" ] || cv_fail "expected placed got $(jq -r '.order.status' <<<"$B")" $LINENO
[ "$(jq -r '.order.items | length' <<<"$B")" = "2" ] || cv_fail "expected 2 items got $(jq -r '.order.items | length' <<<"$B")" $LINENO
[ "$(jq -r --argjson p "$PB" '.order.items[] | select(.productId==$p) | "\(.name)|\(.quantity)|\(.unitPriceCents)|\(.lineTotalCents)"' <<<"$B")" = "CV gone $CV_SUFFIX|3|700|2100" ] || cv_fail "expected removed product line preserved" $LINENO
[ "$(jq -r '.order.subtotalCents' <<<"$B")" = "3100" ] || cv_fail "expected subtotal 3100" $LINENO
[ "$(jq -r '.order.shippingCents' <<<"$B")" = "599" ] || cv_fail "expected shipping 599" $LINENO
[ "$(jq -r '.order.totalCents' <<<"$B")" = "3699" ] || cv_fail "expected total 3699" $LINENO
[ "$(jq -r '.order.createdAt | type' <<<"$B")" = "string" ] || cv_fail "expected createdAt" $LINENO
[ "$(jq -r --argjson p "$PA" '.order.items[] | select(.productId==$p) | .available' <<<"$B")" = "true" ] || cv_fail "expected in-stock product $PA available=true" $LINENO
[ "$(jq -r --argjson p "$PB" '.order.items[] | select(.productId==$p) | .available' <<<"$B")" = "false" ] || cv_fail "expected removed product $PB available=false" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:shopper_opens_own_order_active"
