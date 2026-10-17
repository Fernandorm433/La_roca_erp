-- Script para crear la estructura de Laboratorio

CREATE TABLE IF NOT EXISTS muestras_laboratorio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_despacho UUID, -- Referencia a despachos_produccion (puede ser NULL para el histórico)
    codigo_laboratorio TEXT,
    orden_carguio TEXT,
    n_carguio INTEGER,
    requerimiento TEXT,
    diseno TEXT,
    vaciado TEXT,
    cliente TEXT,
    fecha DATE,
    v_salida NUMERIC,
    ubicacion TEXT,
    operador TEXT,
    mixer TEXT,
    elemento TEXT,
    regulacion TEXT,
    n_roturas TEXT,
    acelerante TEXT,
    f_rotura_acelerante DATE,
    f_rotura_3d DATE,
    f_rotura_7d DATE,
    f_rotura_14d DATE,
    f_rotura_28d DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roturas_probetas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_muestra UUID REFERENCES muestras_laboratorio(id) ON DELETE CASCADE,
    tipo_rotura TEXT, -- '3D', '7D', '14D', '28D', 'ACELERANTE'
    fecha_programada DATE,
    fecha_real DATE,
    diametro NUMERIC,
    altura NUMERIC,
    peso NUMERIC,
    carga_rotura NUMERIC,
    resistencia_calculada NUMERIC,
    responsable TEXT,
    estado TEXT DEFAULT 'Pendiente', -- Pendiente, Realizado
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
