#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1255413916_20261026130330/api/_infra.sh

# Given
cv_step Given "a shopper ordered three products; one stays listed in stock, one is removed from the catalog, one is out of stock" $LINENO
cv_register_user staff staff; STAFF=$CV_TOKEN
cv_register_user shopper; TOK=$CV_TOKEN
cv_seed_product 1000 10; PA=$CV_PRODUCT_ID
cv_seed_product 1100 10; PB=$CV_PRODUCT_ID
cv_seed_product 1200 10; PC=$CV_PRODUCT_ID
cv_add_to_cart "$TOK" "$PA" 1
cv_add_to_cart "$TOK" "$PB" 1
cv_add_to_cart "$TOK" "$PC" 1
cv_checkout "$TOK"; OID=$CV_ORDER_ID
cv_prereq "remove product $PB from the catalog" $LINENO
cv_http DELETE "/products/$PB" "" -H "Authorization: Bearer $STAFF"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 removing product $PB got $CV_HTTP_STATUS" $LINENO
cv_prereq "set stock of product $PC to 0" $LINENO
cv_http PATCH "/products/$PC" '{"stock":0}' -H "Authorization: Bearer $STAFF"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 setting stock of $PC to 0 got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" -H "Authorization: Bearer $TOK"
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY

# Then
cv_step Then "only the listed in-stock product's line is available; removed and out-of-stock lines are not" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 from GET /orders got $LIST_STATUS" $LINENO
O=$(jq -c --argjson id "$OID" '.orders[] | select(.id==$id)' <<<"$LIST_BODY")
[ -n "$O" ] || cv_fail "expected order $OID in list got none" $LINENO
cv_jeq "$O" '.items | length' 3 "order.items length" $LINENO
cv_jeq "$O" "[.items[] | select(.productId==$PA) | .available][0]" true "available for listed in-stock product $PA" $LINENO
cv_jeq "$O" "[.items[] | select(.productId==$PB) | .available][0]" false "available for removed product $PB" $LINENO
cv_jeq "$O" "[.items[] | select(.productId==$PC) | .available][0]" false "available for out-of-stock product $PC" $LINENO

# Cleanup
cv_step Cleanup "remove users, orders and products created by this test" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_show_line_availability_based_on_current_product_state"
