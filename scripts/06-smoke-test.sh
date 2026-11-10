#!/usr/bin/env bash
set -euo pipefail
source scripts/_common.sh
MODE="${1:-test}"
if [[ "$MODE" == 'mock' || "$MODE" == 'test' ]]; then
  ID=$(get_api_id "$TEST_NAME")
  URL="https://${ID}.execute-api.${AWS_REGION}.amazonaws.com/test/clientes/CLI001/cuentas"
  EXPECTED=200
  BODY=$(mktemp)
  # Origen esperado según el modo (MOCK o LAMBDA)
  if [[ "$MODE" == 'test' ]]; then ORIGEN='LAMBDA'; else ORIGEN='MOCK'; fi
  # Tras create-deployment el stage tarda unos segundos en propagarse:
  # se reintenta hasta ver el origen esperado (máx. 12 intentos, 10 s entre ellos).
  CODE=''
  for i in {1..12}; do
    CODE=$(curl --retry 5 --retry-delay 3 --retry-all-errors -sS -o "$BODY" -w '%{http_code}' "$URL")
    if [[ "$CODE" == "$EXPECTED" ]] && grep -q "\"origen\":\"${ORIGEN}\"" "$BODY"; then break; fi
    echo "Intento ${i}/12: HTTP ${CODE}, aún sin origen ${ORIGEN}; reintentando..."
    sleep 10
  done
  [[ "$CODE" == "$EXPECTED" ]] || { cat "$BODY"; echo "HTTP ${CODE}, esperado ${EXPECTED}"; exit 1; }
  grep -q "\"origen\":\"${ORIGEN}\"" "$BODY" || { cat "$BODY"; echo "No llegó a ${ORIGEN}"; exit 1; }
  rm -f "$BODY"
  echo "Smoke ${MODE}: OK 200"
elif [[ "$MODE" == 'prod' ]]; then
  ID=$(get_api_id "$PROD_NAME")
  URL="https://${ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/clientes/CLI001/cuentas"
  KEY_ID=$(aws apigateway get-api-keys --limit 500 --query "items[?name=='mod7-key-${SUFFIX}'].id | [0]" --output text)
  [[ "$KEY_ID" != 'None' ]] || exit 1
  KEY=$(aws apigateway get-api-key --api-key "$KEY_ID" --include-value --query value --output text)
  [[ -n "$KEY" ]] || exit 1
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::add-mask::$KEY"; fi
  # Propagación de Usage Plan; reintentos acotados sin exponer clave.
  for i in {1..12}; do
    WITHOUT=$(curl -sS -o /dev/null -w '%{http_code}' "$URL")
    WITH=$(curl -sS -o /dev/null -w '%{http_code}' -H "x-api-key: $KEY" "$URL")
    if [[ "$WITHOUT" == '403' && "$WITH" == '200' ]]; then break; fi
    sleep 10
  done
  [[ "$WITHOUT" == '403' && "$WITH" == '200' ]] || { echo "Error PROD: sin clave ${WITHOUT}; con clave ${WITH}"; exit 1; }
  echo 'Smoke PROD: sin clave 403; con clave 200'
  bash scripts/06-smoke-test.sh test
else
  echo 'Uso: 06-smoke-test.sh mock|test|prod' >&2; exit 1
fi
