#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper's order containing a product still in the catalog with stock" $LINENO
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product avail 1500 10
PID=$CV_PRODUCT_ID
cv_add_to_cart "$TOKEN" "$PID" 2
cv_checkout "$TOKEN"; OID=$CV_ORDER_ID
[ "$(cv_stock "$PID")" = "8" ] || cv_fail "expected remaining stock 8 got $(cv_stock "$PID")" $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the order line marks the product as available" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
LINE=$(jq -c --argjson o "$OID" --argjson p "$PID" '.orders[] | select(.id==$o) | .items[] | select(.productId==$p)' <<<"$CV_HTTP_BODY")
[ -n "$LINE" ] || cv_fail "expected line for product $PID in order $OID" $LINENO
[ "$(jq -r '.available' <<<"$LINE")" = "true" ] || cv_fail "expected available=true got $(jq -r '.available' <<<"$LINE")" $LINENO
[ "$(jq -r '.quantity' <<<"$LINE")" = "2" ] || cv_fail "expected quantity 2" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:order_line_shows_available_product"
