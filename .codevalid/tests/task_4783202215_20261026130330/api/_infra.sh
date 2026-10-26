#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"
export DATABASE_URL="${DATABASE_URL:-postgresql://app:app@toxiproxy:5432/appdb}"

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url|/path> [json-body] [expected-status] [extra curl args, e.g. -H "Authorization: Bearer $T"]
#          performs the request (relative paths go to $BASE_URL), prints REQUEST_*/RESPONSE_*
#          and CV_HTTP|METHOD|url|status|ms, sets CV_HTTP_STATUS CV_HTTP_BODY CV_HTTP_MS
#          CV_HTTP_BODY_FILE CV_HTTP_HEADERS_FILE. Call it directly, never inside $(...).
#          A 3-digit expected-status (with or without a body) is asserted: a different status
#          fails the test via cv_fail. Omit it to assert on $CV_HTTP_STATUS yourself.
# cv_http  <METHOD> <url> <http_status>          (legacy: marker only, right after your own curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "${1:-}" "${2:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; exit 1; }
_cv_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_cv_now_ms() {
  _cv_n=${EPOCHREALTIME:-}
  if [ -n "$_cv_n" ]; then _cv_secs_to_ms "$_cv_n"; return 0; fi
  _cv_n=$(date +%s%3N 2>/dev/null || true)
  _cv_is_int "$_cv_n" || _cv_n=$(( $(date +%s) * 1000 ))
  printf '%s' "$_cv_n"
}
_cv_ms_file() { printf '%s/.cv_last_ms.%s' "${TMPDIR:-/tmp}" "$$"; }
curl() {
  _cv_t0=$(_cv_now_ms)
  _cv_rc=0
  command curl "$@" || _cv_rc=$?
  _cv_t1=$(_cv_now_ms)
  printf '%s' "$((_cv_t1 - _cv_t0))" > "$(_cv_ms_file)" 2>/dev/null || :
  return $_cv_rc
}
# psql without a connection falls back to a local socket seed-test does not have; when
# DATABASE_URL is set and the call names no connection, connect through it.
psql() {
  if [ -n "${DATABASE_URL:-}" ]; then
    case " $* " in
      *" $DATABASE_URL "*|*" -h "*|*" --host"*|*" -d "*|*" --dbname"*|*"postgres://"*|*"postgresql://"*) ;;
      *) command psql "$DATABASE_URL" "$@"; return $? ;;
    esac
  fi
  command psql "$@"
}
_cv_secs_to_ms() {
  _cv_t=$(printf '%s' "${1:-0}" | tr ',' '.')
  _cv_s=${_cv_t%%.*}
  case "$_cv_t" in *.*) _cv_f=${_cv_t#*.}000 ;; *) _cv_f=000 ;; esac
  _cv_f=${_cv_f%"${_cv_f#???}"}
  while [ "${_cv_f#0}" != "$_cv_f" ]; do _cv_f=${_cv_f#0}; done
  _cv_is_int "$_cv_s" || _cv_s=0
  _cv_is_int "$_cv_f" || _cv_f=0
  printf '%s' "$(( _cv_s * 1000 + _cv_f ))"
}
_cv_is_status() { _cv_is_int "${1:-}" && [ ${#1} -eq 3 ]; }
cv_http() {
  if [ $# -ge 3 ] && [ $# -le 4 ] && _cv_is_status "$3" && { [ $# -eq 3 ] || _cv_is_int "$4"; }      && { [ -n "${4:-}" ] || [ -f "$(_cv_ms_file)" ]; }; then
    _cv_ms=${4:-}
    if [ -z "$_cv_ms" ] && [ -f "$(_cv_ms_file)" ]; then
      _cv_ms=$(cat "$(_cv_ms_file)" 2>/dev/null || true)
      rm -f "$(_cv_ms_file)" 2>/dev/null || :
    fi
    _cv_is_int "$_cv_ms" || _cv_ms=''
    printf 'CV_HTTP|%s|%s|%s%s\n' "$1" "$2" "$3" "${_cv_ms:+|$_cv_ms}"
    return 0
  fi
  _cv_method=${1:-GET}
  _cv_url=${2:-/}
  _cv_data=''
  _cv_expect=''
  if [ $# -ge 2 ]; then shift 2; else shift $#; fi
  if [ $# -ge 1 ] && ! _cv_is_status "$1"; then
    case "$1" in -*) ;; *) _cv_data=$1; shift ;; esac
  fi
  if [ $# -ge 1 ] && _cv_is_status "$1"; then _cv_expect=$1; shift; fi
  case "$_cv_url" in /*) _cv_url="${BASE_URL:-http://app:6713}$_cv_url" ;; esac
  CV_HTTP_BODY_FILE="${TMPDIR:-/tmp}/cv_http_body.$$"
  CV_HTTP_HEADERS_FILE="${TMPDIR:-/tmp}/cv_http_headers.$$"
  : > "$CV_HTTP_BODY_FILE"; : > "$CV_HTTP_HEADERS_FILE"
  printf 'REQUEST_HEADERS:\n%s %s\n' "$_cv_method" "$_cv_url"
  printf 'REQUEST_BODY:\n%s\n' "$_cv_data"
  if [ -n "$_cv_data" ]; then
    _cv_w=$(command curl -sS -X "$_cv_method" -H 'Content-Type: application/json' --data "$_cv_data" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  else
    _cv_w=$(command curl -sS -X "$_cv_method" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  fi
  CV_HTTP_STATUS=${_cv_w%% *}
  _cv_is_int "$CV_HTTP_STATUS" || CV_HTTP_STATUS=000
  case "$_cv_w" in *' '*) CV_HTTP_MS=$(_cv_secs_to_ms "${_cv_w#* }") ;; *) CV_HTTP_MS=0 ;; esac
  CV_HTTP_BODY=$(cat "$CV_HTTP_BODY_FILE" 2>/dev/null || true)
  printf 'RESPONSE_HEADERS:\n'; cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true
  printf 'RESPONSE_BODY:\n%s\n' "$CV_HTTP_BODY"
  rm -f "$(_cv_ms_file)" 2>/dev/null || :
  printf 'CV_HTTP|%s|%s|%s|%s\n' "$_cv_method" "$_cv_url" "$CV_HTTP_STATUS" "$CV_HTTP_MS"
  if [ -n "$_cv_expect" ] && [ "$CV_HTTP_STATUS" != "$_cv_expect" ]; then
    cv_fail "expected HTTP $_cv_expect from $_cv_method $_cv_url got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" ""
  fi
  return 0
}
# --- end CodeValid diagnosis markers ---

# --- feature helpers ---
CV_SUFFIX="$(date +%s%N)${RANDOM}"
CV_USER_IDS=(); CV_PRODUCT_IDS=()

cv_sql() { psql -X -q -t -A -v ON_ERROR_STOP=1 -c "$1"; }

# cv_register_user <label> [customer|staff] -> CV_USER_ID, CV_TOKEN
cv_register_user() {
  local label=$1 role=${2:-customer}
  local email="cv_${label}_${CV_SUFFIX}@example.com" pw="Passw0rd!${CV_SUFFIX}"
  cv_prereq "register $role user $email" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$email" --arg n "CV $label" --arg p "$pw" '{email:$e,name:$n,password:$p}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $email got $CV_HTTP_STATUS" $LINENO
  CV_USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id')
  _cv_is_int "$CV_USER_ID" || cv_fail "expected user id got '$CV_USER_ID'" $LINENO
  CV_USER_IDS+=("$CV_USER_ID")
  if [ "$role" = "staff" ]; then
    cv_sql "UPDATE users SET role='staff' WHERE id=$CV_USER_ID" >/dev/null || cv_fail "could not promote user to staff" $LINENO
  fi
  cv_http POST /auth/login "$(jq -nc --arg e "$email" --arg p "$pw" '{email:$e,password:$p}')"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 logging in $email got $CV_HTTP_STATUS" $LINENO
  CV_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
  [ -n "$CV_TOKEN" ] && [ "$CV_TOKEN" != "null" ] || cv_fail "expected login token got none" $LINENO
}

# cv_seed_product <price_cents> <stock> -> CV_PRODUCT_ID
cv_seed_product() {
  cv_prereq "seed product price=$1 stock=$2" $LINENO
  CV_PRODUCT_ID=$(cv_sql "INSERT INTO products (name, category, price_cents, stock) VALUES ('CV Product $CV_SUFFIX $RANDOM', 'cv-test', $1, $2) RETURNING id" | head -n1) \
    || cv_fail "could not seed product" $LINENO
  _cv_is_int "$CV_PRODUCT_ID" || cv_fail "expected product id got '$CV_PRODUCT_ID'" $LINENO
  CV_PRODUCT_IDS+=("$CV_PRODUCT_ID")
}

# cv_add_to_cart <token> <productId> <qty>
cv_add_to_cart() {
  cv_prereq "add product $2 x$3 to cart" $LINENO
  cv_http POST /cart/items "$(jq -nc --argjson p "$2" --argjson q "$3" '{productId:$p,quantity:$q}')" -H "Authorization: Bearer $1"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 adding to cart got $CV_HTTP_STATUS" $LINENO
}

# cv_checkout <token> -> CV_ORDER_ID (201 asserted)
cv_checkout() {
  cv_prereq "checkout" $LINENO
  cv_http POST /orders/checkout '{}' -H "Authorization: Bearer $1"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from checkout got $CV_HTTP_STATUS" $LINENO
  CV_ORDER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.id')
  _cv_is_int "$CV_ORDER_ID" || cv_fail "expected order id got '$CV_ORDER_ID'" $LINENO
}

# cv_placed_order <customer-label> -> registers customer (CV_CUST_ID, CV_CUST_TOKEN), places an order (CV_ORDER_ID)
cv_placed_order() {
  cv_register_user "$1" customer
  CV_CUST_ID=$CV_USER_ID; CV_CUST_TOKEN=$CV_TOKEN
  cv_seed_product 1500 10
  cv_add_to_cart "$CV_CUST_TOKEN" "$CV_PRODUCT_ID" 2
  cv_checkout "$CV_CUST_TOKEN"
  local st; st=$(cv_sql "SELECT status FROM orders WHERE id=$CV_ORDER_ID") || cv_fail "could not read order status" $LINENO
  [ "$st" = "placed" ] || cv_fail "expected new order status placed got '$st'" $LINENO
}

cv_order_status() { cv_sql "SELECT status FROM orders WHERE id=$1"; }

cv_cleanup() {
  local u p
  for u in "${CV_USER_IDS[@]:-}"; do
    [ -n "$u" ] || continue
    cv_sql "DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE user_id=$u); DELETE FROM orders WHERE user_id=$u; DELETE FROM cart_items WHERE user_id=$u; DELETE FROM users WHERE id=$u;" >/dev/null 2>&1 || true
  done
  for p in "${CV_PRODUCT_IDS[@]:-}"; do
    [ -n "$p" ] || continue
    cv_sql "DELETE FROM cart_items WHERE product_id=$p; DELETE FROM products WHERE id=$p AND NOT EXISTS (SELECT 1 FROM order_items WHERE product_id=$p)" >/dev/null 2>&1 || true
  done
  CV_USER_IDS=(); CV_PRODUCT_IDS=()
}
trap cv_cleanup EXIT
