-- Tabla de Caja General
CREATE TABLE IF NOT EXISTS tesoreria_caja (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  tipo TEXT NOT NULL CHECK (tipo IN ('INGRESO', 'SALIDA')),
  monto NUMERIC(10,2) NOT NULL DEFAULT 0,
  descripcion TEXT NOT NULL,
  comprobante TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Caja Chica
CREATE TABLE IF NOT EXISTS tesoreria_caja_chica (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  tipo TEXT NOT NULL DEFAULT 'SALIDA' CHECK (tipo IN ('INGRESO', 'SALIDA')),
  monto NUMERIC(10,2) NOT NULL DEFAULT 0,
  descripcion TEXT NOT NULL,
  responsable TEXT NOT NULL,
  comprobante TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- MIGRACIÓN PARA CAJA CHICA (Si la tabla ya existe)
-- EJECUTAR EN SUPABASE:
-- ALTER TABLE tesoreria_caja_chica ADD COLUMN tipo TEXT NOT NULL DEFAULT 'SALIDA' CHECK (tipo IN ('INGRESO', 'SALIDA'));

-- Tabla de Aspectos Legales
CREATE TABLE IF NOT EXISTS tesoreria_legal (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  tipo_documento TEXT,
  fecha_vencimiento DATE,
  estado TEXT DEFAULT 'VIGENTE',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
