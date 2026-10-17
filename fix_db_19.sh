#!/bin/bash
API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
URL="http://167.233.215.224:8000/rest/v1/despachos_produccion"

curl -X POST "$URL" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "fecha":"2026-05-29",
    "orden_carguio":19,
    "cliente":"CONSUELO NIETO DE RODRIGUEZ",
    "operador":"ALEJO",
    "mixer":"CMX 44",
    "volumen":10.25,
    "diseno":"210",
    "optimizado":"nan",
    "volumen_guias":10.50,
    "diseno_guias":"210.0",
    "bomba":null,
    "piedra_12":4525.0,
    "piedra_34":3765.0,
    "piedra_38":0.0,
    "arena":10250.0,
    "cemento":3015.0,
    "agua":1572.5,
    "aditivo":25.9,
    "estado":"programada"
  }'
