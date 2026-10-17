-- ========================================================
-- TABLA DE DISEÑOS DE MEZCLA (RECETAS DE PLANTA)
-- Ejecutar en el Editor SQL de Supabase (o Hetzner)
-- ========================================================

CREATE TABLE IF NOT EXISTS public.disenos_mezcla (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    resistencia TEXT NOT NULL,
    huso TEXT NOT NULL DEFAULT '67',
    tipo_vaciado TEXT NOT NULL DEFAULT 'BOMBEABLE',
    cemento_kg NUMERIC(10, 2) NOT NULL DEFAULT 0,
    arena_kg NUMERIC(10, 2) NOT NULL DEFAULT 0,
    piedra_total_kg NUMERIC(10, 2) NOT NULL DEFAULT 0,
    piedra_12_porcentaje NUMERIC(5, 2) NOT NULL DEFAULT 100,
    piedra_34_porcentaje NUMERIC(5, 2) NOT NULL DEFAULT 0,
    piedra_38_porcentaje NUMERIC(5, 2) NOT NULL DEFAULT 0,
    arena_1_porcentaje NUMERIC(5, 2) NOT NULL DEFAULT 100,
    arena_2_porcentaje NUMERIC(5, 2) NOT NULL DEFAULT 0,
    agua_lt NUMERIC(10, 2) NOT NULL DEFAULT 0,
    aditivo_kg NUMERIC(10, 2) NOT NULL DEFAULT 0,
    activo BOOLEAN DEFAULT true,
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    actualizado_en TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.disenos_mezcla ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir acceso total a disenos_mezcla"
ON public.disenos_mezcla
FOR ALL USING (true);

-- Insertar recetas históricas extraídas de Google Sheets:

INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210E', '57', 'BOMBEABLE', 271.7, 1011.9, 802.0, 76.1, 23.9, 0.0, 100.0, 0.0, 152.3, 2.05);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210', '67', 'BOMBEABLE', 278.1, 997.6, 813.2, 89.9, 10.1, 0.0, 100.0, 0.0, 145.2, 2.14);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210E', '67', 'BOMBEABLE', 273.1, 992.1, 804.2, 92.8, 7.2, 0.0, 100.0, 0.0, 145.9, 2.05);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210', '57', 'BOMBEABLE', 279.5, 1002.0, 821.2, 67.2, 32.8, 0.0, 100.0, 0.0, 135.8, 2.16);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('245', '67', 'BOMBEABLE', 305.1, 968.4, 820.9, 88.7, 11.3, 0.0, 100.0, 0.0, 144.0, 2.31);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210', '57', 'DIRECTO', 263.6, 1030.8, 834.3, 75.5, 24.5, 0.0, 100.0, 0.0, 141.8, 1.98);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210', '67', 'DIRECTO', 267.1, 1025.4, 819.5, 90.9, 9.1, 0.0, 100.0, 0.0, 136.7, 2.02);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('175', '57', 'DIRECTO', 251.5, 1025.5, 842.2, 76.1, 23.9, 0.0, 100.0, 0.0, 140.2, 1.95);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('280', '67', 'BOMBEABLE', 327.0, 941.4, 815.9, 90.9, 9.1, 0.0, 100.0, 0.0, 148.8, 2.45);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('100', '67', 'BOMBEABLE', 228.1, 1199.5, 592.2, 95.1, 4.9, 0.0, 100.0, 0.0, 146.5, 1.82);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('280', '57', 'BOMBEABLE', 325.4, 959.4, 821.1, 74.5, 25.5, 0.0, 100.0, 0.0, 137.4, 2.49);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('245', '57', 'BOMBEABLE', 305.3, 963.6, 817.1, 76.6, 23.4, 0.0, 100.0, 0.0, 163.3, 2.35);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('175', '67', 'BOMBEABLE', 256.2, 1052.1, 787.8, 89.3, 10.7, 0.0, 100.0, 0.0, 134.8, 1.94);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('100', '57', 'BOMBEABLE', 215.4, 1080.9, 788.2, 65.2, 34.8, 0.0, 100.0, 0.0, 129.8, 1.79);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('240', '57', 'BOMBEABLE', 298.3, 979.0, 815.8, 78.6, 21.4, 0.0, 100.0, 0.0, 150.7, 2.25);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('175', '67', 'DIRECTO', 250.0, 1013.2, 839.2, 91.1, 8.9, 0.0, 100.0, 0.0, 120.5, 1.92);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('245', '57', 'DIRECTO', 300.0, 977.2, 826.2, 73.5, 26.5, 0.0, 100.0, 0.0, 140.0, 2.27);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('175', '57', 'BOMBEABLE', 255.2, 1042.9, 788.9, 74.8, 25.2, 0.0, 100.0, 0.0, 132.3, 1.95);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('240', '67', 'BOMBEABLE', 303.9, 962.7, 827.0, 92.2, 7.8, 0.0, 100.0, 0.0, 153.8, 2.34);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('100', '57', 'DIRECTO', 210.3, 1047.2, 816.2, 74.3, 25.7, 0.0, 100.0, 0.0, 120.5, 1.80);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('320', '67', 'DIRECTO', 335.0, 910.3, 862.7, 93.3, 6.7, 0.0, 100.0, 0.0, 133.1, 2.57);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('280', '57', 'DIRECTO', 812.5, 2540.3, 2209.7, 75.4, 24.6, 0.0, 100.0, 0.0, 388.2, 6.22);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('350', '57', 'DIRECTO', 368.5, 881.1, 860.8, 79.1, 20.9, 0.0, 100.0, 0.0, 123.8, 2.63);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('350', '67', 'BOMBEABLE', 365.0, 900.4, 844.6, 100.0, 0.0, 0.0, 100.0, 0.0, 138.6, 2.77);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('350', '67', 'DIRECTO', 360.6, 869.1, 857.1, 100.0, 0.0, 0.0, 100.0, 0.0, 119.4, 2.65);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('175', '89', 'BOMBEABLE', 261.0, 1219.5, 573.6, 42.0, 0.0, 58.0, 100.0, 0.0, 148.1, 2.34);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('100', '67', 'DIRECTO', 210.0, 1037.6, 816.9, 78.0, 22.0, 0.0, 100.0, 0.0, 143.2, 1.80);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('320', '57', 'BOMBEABLE', 345.0, 957.8, 836.9, 74.0, 26.0, 0.0, 100.0, 0.0, 162.0, 2.66);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('245', '67', 'DIRECTO', 300.0, 957.9, 834.0, 100.0, 0.0, 0.0, 100.0, 0.0, 134.7, 2.29);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('140', '67', 'BOMBEABLE', 270.0, 1489.9, 962.7, 100.0, 0.0, 0.0, 100.0, 0.0, 200.0, 2.66);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('420', '67', 'BOMBEABLE', 430.0, 844.0, 867.0, 100.0, 0.0, 0.0, 100.0, 0.0, 148.3, 3.51);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('280', '67', 'DIRECTO', 315.0, 924.0, 842.1, 87.5, 12.5, 0.0, 100.0, 0.0, 110.0, 2.32);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('140', '57', 'DIRECTO', 220.0, 1016.4, 883.0, 80.0, 20.0, 0.0, 100.0, 0.0, 145.0, 1.89);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('140', '67', 'DIRECTO', 225.0, 1050.8, 832.7, 100.0, 0.0, 0.0, 100.0, 0.0, 142.5, 1.85);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210E', '67', 'DIRECTO', 270.0, 1008.0, 818.0, 100.0, 0.0, 0.0, 100.0, 0.0, 145.0, 1.99);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('210E', '57', 'DIRECTO', 270.0, 1008.0, 831.0, 75.0, 25.0, 0.0, 100.0, 0.0, 140.0, 1.99);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('240', '67', 'DIRECTO', 295.0, 993.5, 798.3, 100.0, 0.0, 0.0, 100.0, 0.0, 145.0, 2.26);
INSERT INTO public.disenos_mezcla (resistencia, huso, tipo_vaciado, cemento_kg, arena_kg, piedra_total_kg, piedra_12_porcentaje, piedra_34_porcentaje, piedra_38_porcentaje, arena_1_porcentaje, arena_2_porcentaje, agua_lt, aditivo_kg) VALUES ('320', '67', 'BOMBEABLE', 345.0, 937.4, 837.2, 100.0, 0.0, 0.0, 100.0, 0.0, 155.0, 2.62);
