#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's order containing a product since removed from the catalog" $LINENO
cv_new_user staff staff
STAFF=$CV_TOKEN
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product removed 1300 10
PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PID" 1
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
cv_http DELETE "/products/$PID" "" 200 -H "Authorization: Bearer $STAFF"
cv_http GET "/products/$PID" "" 404

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the line still lists the product but marks it not available" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
LINE=$(jq -c --argjson o "$OID" --argjson p "$PID" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p)' <<<"$CV_HTTP_BODY")
[ -n "$LINE" ] || cv_fail "expected removed product $PID still listed in order $OID" $LINENO
[ "$(jq -r '.name' <<<"$LINE")" = "CV removed $CV_SUFFIX" ] || cv_fail "expected historical name got $(jq -r '.name' <<<"$LINE")" $LINENO
[ "$(jq -r '.unitPriceCents' <<<"$LINE")" = "1300" ] || cv_fail "expected unitPriceCents 1300" $LINENO
[ "$(jq -r '.available' <<<"$LINE")" = "false" ] || cv_fail "expected available=false got $(jq -r '.available' <<<"$LINE")" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_line_shows_removed_product_as_not_available"
