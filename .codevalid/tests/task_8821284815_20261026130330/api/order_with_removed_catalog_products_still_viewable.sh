#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's order whose products were all removed from the catalog" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product first 1500 5
PA=$CV_PRODUCT_ID
cv_new_product second 900 5
PB=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PA" 2
cv_add_to_cart "$TOKEN" "$PB" 1
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
cv_http DELETE "/products/$PA" "" 200 -H "Authorization: Bearer $STAFF"
cv_http DELETE "/products/$PB" "" 200 -H "Authorization: Bearer $STAFF"
cv_http GET "/products/$PA" "" 404

# When
cv_step When "the shopper opens the order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "all line items keep their names, prices and quantities" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
B=$CV_HTTP_BODY
[ "$(jq -r '.order.items | length' <<<"$B")" = "2" ] || cv_fail "expected 2 items got $(jq -r '.order.items | length' <<<"$B")" $LINENO
[ "$(jq -r --argjson p "$PA" '.order.items[] | select(.productId==$p) | "\(.name)|\(.quantity)|\(.unitPriceCents)|\(.lineTotalCents)"' <<<"$B")" = "CV first $CV_SUFFIX|2|1500|3000" ] || cv_fail "expected first product line preserved" $LINENO
[ "$(jq -r --argjson p "$PB" '.order.items[] | select(.productId==$p) | "\(.name)|\(.quantity)|\(.unitPriceCents)|\(.lineTotalCents)"' <<<"$B")" = "CV second $CV_SUFFIX|1|900|900" ] || cv_fail "expected second product line preserved" $LINENO
[ "$(jq -r '.order.subtotalCents' <<<"$B")" = "3900" ] || cv_fail "expected subtotal 3900" $LINENO
[ "$(jq -r '.order.status' <<<"$B")" = "placed" ] || cv_fail "expected placed" $LINENO
[ "$(jq -r '[.order.items[].available] | map(tostring) | join(",")' <<<"$B")" = "false,false" ] || cv_fail "expected both removed lines available=false got $(jq -c '[.order.items[].available]' <<<"$B")" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_with_removed_catalog_products_still_viewable"
