#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper with a past order of two products, both since removed from the catalog" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product gone1 1100 5
P1=$CV_PRODUCT_ID
cv_new_product gone2 2200 5
P2=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$P1" 1
cv_add_to_cart "$TOKEN" "$P2" 2
cv_checkout "$TOKEN"
OID=$CV_ORDER_ID
for p in "$P1" "$P2"; do
  cv_http DELETE "/products/$p" "" -H "Authorization: Bearer $STAFF"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected product $p removal 200 got $CV_HTTP_STATUS" $LINENO
done
cv_http GET "/products/$P1" ""
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected removed product to be 404 got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the order still lists both removed products with historical details" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
ORDER=$(jq -c --argjson o "$OID" '.orders[] | select(.id==$o)' <<<"$CV_HTTP_BODY")
[ -n "$ORDER" ] || cv_fail "expected order $OID in history" $LINENO
I1=$(jq -c --argjson p "$P1" '.items[] | select(.productId==$p)' <<<"$ORDER")
I2=$(jq -c --argjson p "$P2" '.items[] | select(.productId==$p)' <<<"$ORDER")
[ -n "$I1" ] || cv_fail "expected removed product $P1 in order items" $LINENO
[ -n "$I2" ] || cv_fail "expected removed product $P2 in order items" $LINENO
[ "$(jq -r '.name' <<<"$I1")" = "CV gone1 $CV_SUFFIX" ] || cv_fail "expected name 'CV gone1 $CV_SUFFIX' got $(jq -r '.name' <<<"$I1")" $LINENO
[ "$(jq -r '.unitPriceCents' <<<"$I1")" = "1100" ] || cv_fail "expected unitPriceCents 1100" $LINENO
[ "$(jq -r '.quantity' <<<"$I1")" = "1" ] || cv_fail "expected quantity 1" $LINENO
[ "$(jq -r '.name' <<<"$I2")" = "CV gone2 $CV_SUFFIX" ] || cv_fail "expected name 'CV gone2 $CV_SUFFIX' got $(jq -r '.name' <<<"$I2")" $LINENO
[ "$(jq -r '.unitPriceCents' <<<"$I2")" = "2200" ] || cv_fail "expected unitPriceCents 2200" $LINENO
[ "$(jq -r '.quantity' <<<"$I2")" = "2" ] || cv_fail "expected quantity 2" $LINENO
[ "$(jq -r '.lineTotalCents' <<<"$I2")" = "4400" ] || cv_fail "expected lineTotalCents 4400" $LINENO
[ "$(jq -r '.available' <<<"$I1")" = "false" ] || cv_fail "expected removed product $P1 available=false got $(jq -r '.available' <<<"$I1")" $LINENO
[ "$(jq -r '.available' <<<"$I2")" = "false" ] || cv_fail "expected removed product $P2 available=false got $(jq -r '.available' <<<"$I2")" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_history_shows_removed_catalog_products"
