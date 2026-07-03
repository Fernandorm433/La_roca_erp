import "@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // Manejo de preflight CORS (OPCIONES)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const data = await req.json();
    console.log("Datos recibidos para SUNAT:", data);

    const { 
      tipoDoc, 
      serie, 
      correlativo, 
      clienteDocumento, 
      montoTotal, 
      cotizacionId, 
      anticipada 
    } = data;

    // 1. Validaciones básicas
    if (!tipoDoc || !serie || !correlativo) {
      throw new Error("Faltan parámetros obligatorios (tipoDoc, serie, correlativo).");
    }

    // 2. GENERACIÓN DEL XML UBL 2.1 Y FIRMA (SIMULADA POR AHORA HASTA TENER EL .PFX)
    /* 
      Aquí iría la lógica usando xmldom y xml-crypto para construir el UBL:
      const doc = new DOMParser().parseFromString(xmlString);
      const sig = new SignedXml();
      sig.addReference("//*[local-name(.)='ExtensionContent']");
      sig.computeSignature(xmlString);
    */
    
    // Hash generado por la "firma"
    const mockHash = btoa(`HASH-${serie}-${correlativo}-${Date.now()}`);

    // 3. ACTUALIZAR BASE DE DATOS
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: { Authorization: req.headers.get('Authorization')! },
      },
    });

    if (tipoDoc === '01' || tipoDoc === '03') {
      // Es Factura o Boleta
      if (!cotizacionId) throw new Error("Falta cotizacionId para facturación");
      
      const { error: dbError } = await supabase
        .from('facturacion_sunat')
        .insert({
          cotizacion_id: cotizacionId,
          tipo_comprobante: tipoDoc,
          serie: serie,
          correlativo: correlativo,
          monto_total: montoTotal || 0,
          anticipada: anticipada || false,
          estado_sunat: 'ACEPTADO',
          hash: mockHash,
        });

      if (dbError) {
        console.error("Error DB Factura:", dbError);
        throw dbError;
      }
      
    } else if (tipoDoc === '09') {
      // Es Guía de Remisión Remitente (GRE)
      if (!cotizacionId) throw new Error("Falta cotizacionId para GRE");
      
      const { error: dbError } = await supabase
        .from('guias_remision')
        .insert({
          cotizacion_id: cotizacionId,
          serie: serie,
          correlativo: correlativo,
          cliente_documento: clienteDocumento || '',
          estado_sunat: 'ACEPTADO',
          hash: mockHash,
        });

      if (dbError) {
        console.error("Error DB Guia:", dbError);
        throw dbError;
      }
    }

    // Respuesta simulada de la SUNAT
    const mockResponse = {
      status: "success",
      sunat_response: {
        codigo: 0,
        mensaje: `El Comprobante numero ${serie}-${correlativo} ha sido aceptado (BETA)`,
        hash: mockHash, 
      }
    };

    return new Response(
      JSON.stringify(mockResponse),
      { headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error("Error procesando emisión:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...cors, 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})
