-- Script para crear la tabla de asignación de carguíos a mixeros
-- Ejecutar este script en el Editor SQL de Supabase el 4 de Junio (o en Hetzner)

CREATE TABLE IF NOT EXISTS public.carguios_mixers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    id_venta TEXT NOT NULL, -- Referencia al ID de ventas_programacion (es TEXT, no UUID)
    orden_carga INT NOT NULL DEFAULT 1, -- Ejemplo: 1, 2, 3...
    numero_carguio TEXT NOT NULL DEFAULT '', -- Ejemplo: "CA-2026-1330"
    volumen_carguio NUMERIC(10, 2) NOT NULL DEFAULT 0, -- Ejemplo: 8.5
    operador_id TEXT, -- ID del conductor en la tabla 'conductores' (es TEXT/int, no UUID)
    operador_nombre TEXT, -- Ejemplo: "OSCAR ALVAREZ"
    codigo_mixer TEXT, -- Ejemplo: "CMX 24"
    hora_carguio TEXT, -- Ejemplo: "8:44 a.m."
    estado TEXT DEFAULT 'Pendiente', -- "Pendiente", "En Camino", "En Obra", "Vaciando", "Completado"
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    actualizado_en TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Habilitar RLS (Seguridad a Nivel de Fila)
ALTER TABLE public.carguios_mixers ENABLE ROW LEVEL SECURITY;

-- Política permisiva temporal (ajustar después de la migración)
CREATE POLICY "Permitir acceso a todos en carguios_mixers" 
ON public.carguios_mixers 
FOR ALL USING (true);

-- Habilitar Realtime para que la app reciba cambios en vivo
ALTER PUBLICATION supabase_realtime ADD TABLE public.carguios_mixers;
