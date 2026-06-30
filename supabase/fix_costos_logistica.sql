-- 1. Deshabilitar RLS para la tabla que ya tienes (recepcion_materiales)
ALTER TABLE recepcion_materiales DISABLE ROW LEVEL SECURITY;

-- 2. Crear tabla de categorías de costo (si no existe)
CREATE TABLE IF NOT EXISTS categorias_costo (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  color TEXT DEFAULT '0xFF808080',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE categorias_costo DISABLE ROW LEVEL SECURITY;

-- 3. Crear tabla de gastos operativos
CREATE TABLE IF NOT EXISTS gastos_operativos (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  categoria_id UUID REFERENCES categorias_costo(id),
  descripcion TEXT NOT NULL,
  proveedor TEXT,
  monto NUMERIC(10,2) NOT NULL DEFAULT 0,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE gastos_operativos DISABLE ROW LEVEL SECURITY;

-- 4. Crear tabla de presupuestos mensuales
CREATE TABLE IF NOT EXISTS presupuestos_mensuales (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  categoria_id UUID REFERENCES categorias_costo(id),
  periodo TEXT NOT NULL, -- Ej: '2026-06'
  monto_asignado NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE presupuestos_mensuales DISABLE ROW LEVEL SECURITY;

-- Insertar algunas categorías por defecto para que no esté vacío
INSERT INTO categorias_costo (nombre, color) 
VALUES 
  ('Combustible', '0xFFE53935'),
  ('Mantenimiento', '0xFF43A047'),
  ('Administrativo', '0xFF1E88E5'),
  ('Planilla', '0xFF8E24AA'),
  ('Varios', '0xFF757575')
ON CONFLICT DO NOTHING;
