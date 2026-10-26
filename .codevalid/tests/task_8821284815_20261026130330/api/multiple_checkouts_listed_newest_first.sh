#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_8821284815_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper and a product in stock" $LINENO
cv_new_user shopper
TOKEN=$CV_TOKEN
cv_new_product multi 1000 20
PID=$CV_PRODUCT_ID

# When
cv_step When "the shopper checks out three times at different times" $LINENO
OIDS=()
for q in 1 2 3; do
  cv_add_to_cart "$TOKEN" "$PID" "$q"
  cv_checkout "$TOKEN"
  _cv_is_int "$CV_ORDER_ID" || cv_fail "expected numeric order id got '$CV_ORDER_ID'" $LINENO
  OIDS+=("$CV_ORDER_ID")
  sleep 1
done

# Then
cv_step Then "history lists the three orders newest first and each opens" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"
LIST=$CV_HTTP_BODY
[ "$(jq -r '.orders | length' <<<"$LIST")" = "3" ] || cv_fail "expected 3 orders got $(jq -r '.orders | length' <<<"$LIST")" $LINENO
GOT=$(jq -r '[.orders[].id] | map(tostring) | join(",")' <<<"$LIST")
WANT="${OIDS[2]},${OIDS[1]},${OIDS[0]}"
[ "$GOT" = "$WANT" ] || cv_fail "expected order ids $WANT got $GOT" $LINENO
SORTED=$(jq -r '[.orders[].createdAt] as $c | ($c == ($c | sort | reverse))' <<<"$LIST")
[ "$SORTED" = "true" ] || cv_fail "expected createdAt descending" $LINENO
i=0
for oid in "${OIDS[@]}"; do
  i=$((i+1))
  cv_http GET "/orders/$oid" "" 200 -H "Authorization: Bearer $TOKEN"
  [ "$(jq -r '.order.id' <<<"$CV_HTTP_BODY")" = "$oid" ] || cv_fail "expected opened order $oid" $LINENO
  [ "$(jq -r '.order.items[0].quantity' <<<"$CV_HTTP_BODY")" = "$i" ] || cv_fail "expected order $oid quantity $i" $LINENO
done

# Cleanup
cv_step Cleanup "remove created data" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:multiple_checkouts_listed_newest_first"
