#!/bin/bash
API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
URL="http://91.98.135.205:8000/rest/v1/despachos_produccion"

# Delete the extra row I inserted
curl -X DELETE "$URL?id=eq.ecc2bf30-c0cc-4026-bae2-a53fe706c784" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $API_KEY"

# Update the original row to 11.0
curl -X PATCH "$URL?id=eq.27b821c9-f091-4329-acf1-99d56400f0b4" \
  -H "apikey: $API_KEY" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "volumen": 11.00,
    "volumen_guias": 11.00,
    "piedra_12": 4850.0,
    "piedra_34": 4040.0,
    "arena": 11000.0,
    "cemento": 3235.0,
    "agua": 1687.0,
    "aditivo": 27.8
  }'
