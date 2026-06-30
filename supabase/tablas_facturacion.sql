-- Añadir columna estado_facturacion a cotizaciones
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS estado_facturacion text DEFAULT 'PENDIENTE';
-- Posibles valores: 'PENDIENTE', 'FACTURADO_ANTICIPADO', 'FACTURADO_FINAL'

-- Tabla para Guías de Remisión
CREATE TABLE IF NOT EXISTS guias_remision (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cotizacion_id uuid REFERENCES cotizaciones(id) ON DELETE CASCADE,
    fecha_emision timestamp with time zone DEFAULT now(),
    serie text NOT NULL,
    correlativo integer NOT NULL,
    cliente_documento text,
    estado_sunat text DEFAULT 'PENDIENTE', -- PENDIENTE, ACEPTADO, RECHAZADO
    hash text,
    url_pdf text,
    creado_en timestamp with time zone DEFAULT now()
);

-- Tabla para Facturación (Boletas/Facturas)
CREATE TABLE IF NOT EXISTS facturacion_sunat (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cotizacion_id uuid REFERENCES cotizaciones(id) ON DELETE CASCADE,
    tipo_comprobante text NOT NULL, -- '01' Factura, '03' Boleta
    serie text NOT NULL,
    correlativo integer NOT NULL,
    monto_total numeric(10,2) NOT NULL,
    anticipada boolean DEFAULT false, -- TRUE si es facturación corporativa antes del despacho
    estado_sunat text DEFAULT 'PENDIENTE', -- PENDIENTE, ACEPTADO, RECHAZADO
    hash text,
    url_pdf text,
    creado_en timestamp with time zone DEFAULT now()
);
