import os

file_path = "lib/screens/logistica/gestor_mixers_page.dart"
with open(file_path, "r") as f:
    content = f.read()

# 5. _buildClientInfo definition
buildClientOrig = """  Widget _buildClientInfo(Map<String, dynamic> v, String bomba) {
    bool hasHuso = v['huso'] != null && v['huso'].toString().trim().isNotEmpty;
    bool hasSlump = v['slump'] != null && v['slump'].toString().trim().isNotEmpty;
    bool hasAditivo = v['aditivo'] != null && v['aditivo'].toString().trim().isNotEmpty && v['aditivo'].toString() != '-';
    bool hasObs = v['observaciones'] != null && v['observaciones'].toString().trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),"""

buildClientNew = """  Widget _buildClientInfo(Map<String, dynamic> v, String bomba, {bool isReadOnly = false}) {
    bool hasHuso = v['huso'] != null && v['huso'].toString().trim().isNotEmpty;
    bool hasSlump = v['slump'] != null && v['slump'].toString().trim().isNotEmpty;
    bool hasAditivo = v['aditivo'] != null && v['aditivo'].toString().trim().isNotEmpty && v['aditivo'].toString() != '-';
    bool hasObs = v['observaciones'] != null && v['observaciones'].toString().trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(v['nombre_razon_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 15), overflow: TextOverflow.ellipsis),
            ),
            if (!isReadOnly && !pantallaOculta)
              IconButton(
                icon: const Icon(Icons.edit_note, color: AppColors.primaryDark, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _mostrarOpcionesEdicion(v),
              ),
          ],
        ),"""
if buildClientOrig in content:
    content = content.replace(buildClientOrig, buildClientNew)
else:
    print("buildClientOrig not found")

# 6. _buildClientInfo calls
content = content.replace("_buildClientInfo(v, bomba),", "_buildClientInfo(v, bomba, isReadOnly: isReadOnly),")


# 7. Body logic
bodyOrig = """      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : ventas.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fire_truck_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No hay programación para esta fecha.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildModernList(isReadOnly),"""
bodyNew = """      body: loading 
          ? const Center(child: CircularProgressIndicator()) 
          : (ventas.isEmpty && ventasInactivas.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fire_truck_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No hay programación para esta fecha.", style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _buildModernList(isReadOnly),"""
content = content.replace(bodyOrig, bodyNew)


# 8. _buildModernList definition update.
# This time I will NOT break the ListView.builder. I will just change ListView.builder to a normal ListView mapping children, but keep all the code inside intact.
# Actually it's easier to just do it via regex or custom script.
modernListOrig = """  Widget _buildModernList(bool isReadOnly) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: ventas.length,
      itemBuilder: (context, index) {
        var v = ventas[index];"""

modernListNew = """  Widget _buildModernList(bool isReadOnly) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...ventas.map((v) => _buildVentaItem(v, isReadOnly, isInactive: false)).toList(),
        if (ventasInactivas.isNotEmpty) ...[
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text("Requerimientos Inactivos del Día", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red.shade800)),
                  ]
                ),
                const SizedBox(height: 16),
                ...ventasInactivas.map((v) => _buildVentaItem(v, true, isInactive: true)).toList(),
              ]
            )
          )
        ]
      ],
    );
  }

  Widget _buildVentaItem(Map<String, dynamic> v, bool isReadOnly, {bool isInactive = false}) {"""

content = content.replace(modernListOrig, modernListNew)


# Fix the end of _buildVentaItem
paddingEndOrig = """                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }"""
paddingEndNew = """                  ),
                ),
              ],
            ),
          ),
        );
  }"""
content = content.replace(paddingEndOrig, paddingEndNew)


# Now apply the inactive styling inside _buildVentaItem
content = content.replace("color: Colors.white,", "color: isInactive ? Colors.white70 : Colors.white,")
content = content.replace("BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))", "if (!isInactive) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))")
content = content.replace("border: Border.all(color: Colors.grey.shade200),", "border: isInactive ? Border.all(color: Colors.red.shade200, width: 1.5) : Border.all(color: Colors.grey.shade200),")
content = content.replace("color: const Color(0xFFF8FAFC),", "color: isInactive ? Colors.red.shade50 : const Color(0xFFF8FAFC),")

headerLogisticoOrig = """                        children: [
                          SizedBox(
                            width: 80,"""
headerLogisticoNew = """                        children: [
                          if (isInactive)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                              child: Text(v['estado'] ?? 'INACTIVO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          SizedBox(
                            width: 80,"""
content = content.replace(headerLogisticoOrig, headerLogisticoNew)

headerLogisticoOrig2 = """                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,"""
headerLogisticoNew2 = """                              Row(
                                children: [
                                  if (isInactive)
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                                      child: Text(v['estado'] ?? 'INACTIVO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  SizedBox(
                                    width: 80,"""
content = content.replace(headerLogisticoOrig2, headerLogisticoNew2)

content = content.replace("enabled: !isReadOnly,", "enabled: !isReadOnly && !isInactive,")

saldo_replace = """Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³","""
saldo_new = """if (!isInactive) Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(balanceado ? "✓ Completo" : "Saldo: ${saldo > 0 ? '+' : ''}${saldo.toStringAsFixed(1)} m³","""
content = content.replace(saldo_replace, saldo_new)

content = content.replace("""// TRIPS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),""", """// TRIPS
                if (!isInactive) Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),""")

with open(file_path, "w") as f:
    f.write(content)
