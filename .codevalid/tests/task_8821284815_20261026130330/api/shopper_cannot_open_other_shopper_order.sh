#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "shopper A has a placed order; shopper B is logged in" $LINENO
cv_new_user owner
TA=$CV_TOKEN
cv_new_user other
TB=$CV_TOKEN
cv_new_product item 1200 5
PID=$CV_PRODUCT_ID
cv_add_to_cart "$TA" "$PID" 1
cv_checkout "$TA"; OID=$CV_ORDER_ID

# When
cv_step When "shopper B requests shopper A's order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $TB"

# Then
cv_step Then "the order is reported as not found and no order data leaks" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.order // empty' <<<"$CV_HTTP_BODY")" = "" ] || cv_fail "expected no order in body" $LINENO
cv_prereq "owner can still open own order" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TA"
[ "$(jq -r '.order.id' <<<"$CV_HTTP_BODY")" = "$OID" ] || cv_fail "expected owner sees order $OID" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:shopper_cannot_open_other_shopper_order"
