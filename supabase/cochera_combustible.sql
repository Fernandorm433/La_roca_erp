-- 1. Tabla Maestra de Vehículos (vinculada a los nombres en despachos_produccion)
CREATE TABLE IF NOT EXISTS public.vehiculos_maestro (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    nombre_vehiculo TEXT NOT NULL UNIQUE, -- Ejemplo: 'MIXER 26', 'CBP 16' (debe coincidir con la liquidación)
    placa TEXT,
    responsable TEXT,
    tipo TEXT, -- 'MIXER', 'BOMBA', etc.
    estado TEXT DEFAULT 'Activo',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabla para el Control de Cochera (Seguridad)
CREATE TABLE IF NOT EXISTS public.registro_cochera (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    fecha DATE NOT NULL,
    id_vehiculo UUID REFERENCES public.vehiculos_maestro(id) ON DELETE CASCADE,
    pernocto BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(fecha, id_vehiculo)
);

-- 3. Tabla para el Control de Combustible (Operadores)
CREATE TABLE IF NOT EXISTS public.registro_combustible (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    fecha DATE NOT NULL,
    id_vehiculo UUID REFERENCES public.vehiculos_maestro(id) ON DELETE CASCADE,
    operador TEXT,
    galones NUMERIC DEFAULT 0,
    monto_total NUMERIC DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Opcional: Insertar algunos vehículos por defecto si la tabla está vacía
INSERT INTO public.vehiculos_maestro (nombre_vehiculo, placa, responsable, tipo)
VALUES 
    ('MIXER 25', 'Z7E-741', 'OSCAR AGÜERO', 'MIXER'),
    ('MIXER 26', 'V6K-738', 'PERCY DELGADO', 'MIXER'),
    ('CBP 12', '', '', 'BOMBA'),
    ('CBP 13', '', '', 'BOMBA'),
    ('CBP 15', '', '', 'BOMBA'),
    ('CBP 16', '', '', 'BOMBA'),
    ('CBP 17', '', '', 'BOMBA'),
    ('CBP 18', '', '', 'BOMBA'),
    ('CBP 21', '', '', 'BOMBA')
ON CONFLICT (nombre_vehiculo) DO NOTHING;
