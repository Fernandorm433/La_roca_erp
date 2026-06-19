-- Actualización para integrar control de pagos en Cotizaciones

ALTER TABLE cotizaciones
ADD COLUMN IF NOT EXISTS monto_pagado NUMERIC(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS estado_pago TEXT DEFAULT 'POR CANCELAR' CHECK (estado_pago IN ('POR CANCELAR', 'SALDO PENDIENTE', 'CANCELADO'));

-- Opcional: Actualizar las cotizaciones existentes a "POR CANCELAR" si su monto_pagado es 0
UPDATE cotizaciones
SET estado_pago = 'POR CANCELAR'
WHERE monto_pagado = 0;
