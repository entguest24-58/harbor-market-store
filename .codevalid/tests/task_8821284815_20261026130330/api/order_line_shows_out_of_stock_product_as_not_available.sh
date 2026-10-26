#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's order containing a cataloged product whose stock is now zero" $LINENO
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product oos 900 3
PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PID" 3
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
[ "$(cv_stock "$PID")" = "0" ] || cv_fail "expected stock 0 got $(cv_stock "$PID")" $LINENO
cv_http GET "/products/$PID" "" 200

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the line still lists the product but marks it not available" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
LINE=$(jq -c --argjson o "$OID" --argjson p "$PID" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p)' <<<"$CV_HTTP_BODY")
[ -n "$LINE" ] || cv_fail "expected product $PID listed in order $OID" $LINENO
[ "$(jq -r '.quantity' <<<"$LINE")" = "3" ] || cv_fail "expected quantity 3" $LINENO
[ "$(jq -r '.available' <<<"$LINE")" = "false" ] || cv_fail "expected available=false got $(jq -r '.available' <<<"$LINE")" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_line_shows_out_of_stock_product_as_not_available"
