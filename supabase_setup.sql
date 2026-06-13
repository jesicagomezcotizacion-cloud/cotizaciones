-- ============================================================
-- SISTEMA DE COTIZACIONES — Setup Supabase
-- Ejecutar en: Supabase → SQL Editor → New query
-- ============================================================

-- 1. USUARIOS DE LA APP (separado de auth.users de Supabase)
CREATE TABLE IF NOT EXISTS usuarios (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  rol         TEXT NOT NULL DEFAULT 'usuario' CHECK (rol IN ('admin','usuario')),
  activo      BOOLEAN DEFAULT true,
  creado_en   TIMESTAMPTZ DEFAULT now(),
  creado_por  UUID REFERENCES usuarios(id)
);

-- 2. COTIZACIONES
CREATE TABLE IF NOT EXISTS cotizaciones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nro_pedido    TEXT NOT NULL,
  fecha         DATE,
  comprador     TEXT,
  sector        TEXT,
  descripcion   TEXT,
  empresa       TEXT,
  firma         TEXT,
  proveedores   JSONB DEFAULT '[]',
  items         JSONB DEFAULT '[]',
  totales       JSONB DEFAULT '[]',
  prov_sel_idx  INTEGER DEFAULT 0,
  best_idx      INTEGER DEFAULT 0,
  is_chg        BOOLEAN DEFAULT false,
  motivo_chg    TEXT,
  cond_pago     TEXT,
  plazo         TEXT,
  obs           TEXT,
  justif        TEXT,
  estado        TEXT DEFAULT 'Borrador',
  creado_por    UUID REFERENCES usuarios(id),
  creado_en     TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- 3. SEGUIMIENTO DE PEDIDOS (pedidos aceptados)
CREATE TABLE IF NOT EXISTS seguimiento (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cotizacion_id UUID REFERENCES cotizaciones(id),
  nro_pedido    TEXT NOT NULL,
  descripcion   TEXT,
  comprador     TEXT,
  sector        TEXT,
  empresa       TEXT,
  prov_sel      TEXT,
  monto         NUMERIC,
  cond_pago     TEXT,
  plazo         TEXT,
  obs           TEXT,
  justif        TEXT,
  estado        TEXT DEFAULT 'Aceptado',
  nro_oc        TEXT,
  fecha_autor   DATE,
  obs_track     TEXT,
  is_chg        BOOLEAN DEFAULT false,
  motivo_chg    TEXT,
  best_name     TEXT,
  best_total    NUMERIC,
  hist_cambios  JSONB DEFAULT '[]',
  creado_por    UUID REFERENCES usuarios(id),
  creado_en     TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- 4. HISTORIAL DE AUDITORÍA (quién hizo qué y cuándo)
CREATE TABLE IF NOT EXISTS auditoria (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tabla       TEXT NOT NULL,
  registro_id UUID,
  accion      TEXT NOT NULL,  -- 'crear', 'editar', 'eliminar', 'aceptar', 'cambiar_proveedor'
  detalle     JSONB,
  usuario_id  UUID REFERENCES usuarios(id),
  usuario_nombre TEXT,
  fecha       TIMESTAMPTZ DEFAULT now()
);

-- 5. ESTADOS PERSONALIZADOS
CREATE TABLE IF NOT EXISTS estados (
  id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre  TEXT UNIQUE NOT NULL,
  orden   INTEGER DEFAULT 0
);

-- Estados por defecto
INSERT INTO estados (nombre, orden) VALUES
  ('Cotizado', 1), ('Aceptado', 2), ('En proceso', 3),
  ('OC Generada', 4), ('Enviado a proveedor', 5),
  ('Entregado', 6), ('Cancelado', 7)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE usuarios     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cotizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE seguimiento  ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria    ENABLE ROW LEVEL SECURITY;
ALTER TABLE estados      ENABLE ROW LEVEL SECURITY;

-- Todos pueden leer/escribir (la app maneja los permisos por rol)
CREATE POLICY "acceso_total" ON usuarios     FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON cotizaciones FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON seguimiento  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON auditoria    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total" ON estados      FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- FUNCIÓN: actualizar timestamp automáticamente
-- ============================================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN NEW.actualizado_en = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_cotizaciones_ts
  BEFORE UPDATE ON cotizaciones
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER tg_seguimiento_ts
  BEFORE UPDATE ON seguimiento
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================
-- USUARIO ADMIN POR DEFECTO
-- (cambiar el email y nombre antes de ejecutar)
-- ============================================================
INSERT INTO usuarios (nombre, email, rol, pass_hash)
VALUES (
  'Jesica Gomez',
  'jesica@cotizaciones.com',
  'admin',
  'b030d0f0d30a94d72fa801007b432b55c54cefcae803aa07009f1ff14289125c'
)
ON CONFLICT (email) DO NOTHING;
