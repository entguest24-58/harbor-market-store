#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a newly registered shopper with no orders" $LINENO
cv_new_user fresh
TOKEN=$CV_TOKEN

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "an empty order list is returned without error" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(jq -r '.orders | type' <<<"$CV_HTTP_BODY")" = "array" ] || cv_fail "expected orders array" $LINENO
[ "$(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" = "0" ] || cv_fail "expected 0 orders got $(jq -r '.orders | length' <<<"$CV_HTTP_BODY")" $LINENO

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_for_shopper_with_no_orders"
