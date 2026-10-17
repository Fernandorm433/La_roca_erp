-- supabase/perfil_rrhh_sync.sql

-- 1. Tabla de Solicitudes
CREATE TABLE IF NOT EXISTS solicitudes_empleados (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  empleado_id uuid, -- ID del auth.user o id de la tabla empleados
  tipo_solicitud text NOT NULL,
  fecha_solicitada date NOT NULL,
  estado text DEFAULT 'Pendiente', -- Pendiente, Aprobado, Rechazado
  comentarios text,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. Tabla de Capacitaciones
CREATE TABLE IF NOT EXISTS capacitaciones (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo text NOT NULL,
  descripcion text,
  fecha_publicacion date DEFAULT CURRENT_DATE,
  archivo_pdf_url text, -- URL del storage o nombre de archivo
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Tabla de Progreso/Encuesta de Capacitaciones
CREATE TABLE IF NOT EXISTS capacitaciones_completadas (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  capacitacion_id uuid REFERENCES capacitaciones(id) ON DELETE CASCADE,
  empleado_id uuid,
  completado boolean DEFAULT false,
  respuestas_encuesta jsonb, -- Guardar respuestas a la encuesta
  fecha_completado timestamp with time zone DEFAULT now(),
  UNIQUE(capacitacion_id, empleado_id)
);

-- 4. Actualizar Asistencia (por si falta hora_salida)
ALTER TABLE asistencia_empleados ADD COLUMN IF NOT EXISTS hora_salida text;

-- =====================================================================
-- INSTRUCCIONES PARA STORAGE (Hacerlo manual desde el panel de Supabase)
-- =====================================================================
-- 1. Crear bucket: 'boletas' (Público o Privado según conveniencia)
-- 2. Crear bucket: 'capacitaciones' (Público)

-- Políticas básicas (opcional, ajusta según necesidad)
-- ALTER TABLE solicitudes_empleados ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE capacitaciones ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE capacitaciones_completadas ENABLE ROW LEVEL SECURITY;
