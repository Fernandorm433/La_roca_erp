import csv
import sys
import datetime

MESES = {
    "enero": "01",
    "febrero": "02",
    "marzo": "03",
    "abril": "04",
    "mayo": "05",
    "junio": "06",
    "julio": "07",
    "agosto": "08",
    "septiembre": "09",
    "octubre": "10",
    "noviembre": "11",
    "diciembre": "12"
}

def parse_date(date_str):
    if not date_str or date_str.strip() in ['-', '#REF!', '']:
        return "NULL"
    date_str = date_str.strip()
    # format: 30/01/2025
    if "/" in date_str:
        parts = date_str.split("/")
        if len(parts) == 3:
            return f"'{parts[2]}-{parts[1].zfill(2)}-{parts[0].zfill(2)}'"
    elif " de " in date_str:
        # e.g., "jueves, 23 de enero de 2025"
        parts = date_str.replace(",", "").split(" ")
        if len(parts) >= 6:
            day = parts[1].zfill(2)
            month = MESES.get(parts[3].lower(), "01")
            year = parts[5]
            return f"'{year}-{month}-{day}'"
    return "NULL"

def escape_sql(val):
    if not val or val.strip() in ['-', '#REF!', '']:
        return "NULL"
    # double single quotes for SQL escaping
    escaped = val.replace("'", "''").strip()
    return f"'{escaped}'"

def parse_num(val):
    if not val or val.strip() in ['-', '#REF!', '']:
        return "NULL"
    try:
        f = float(val)
        return str(f)
    except:
        return "NULL"
        
def parse_int(val):
    if not val or val.strip() in ['-', '#REF!', '']:
        return "NULL"
    try:
        return str(int(float(val)))
    except:
        return "NULL"

input_file = "data.csv"
output_file = "insert_laboratorio.sql"

try:
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        # Skip header rows - since they have newlines, we need to read until we hit actual data.
        # Let's skip until we see a row where column 1 starts with 'LRSC' or 'RLI'
        with open(output_file, 'w', encoding='utf-8') as out:
            out.write("BEGIN;\n")
            
            for row in reader:
                if len(row) < 21:
                    continue
                # column 1 is CODIGO LABOR. (0-indexed: row[1] if row[0] is empty)
                # Looking at data: row[1] is 'LRSC-CC-25-0859'
                codigo = row[1].strip()
                if not codigo.startswith('LRSC') and not codigo.startswith('RLI'):
                    continue
                
                # Extract fields
                # 1: CODIGO LABOR.
                # 2: ORDEN DE CARGUIO
                # 3: N° CARGUIO
                # 4: REQUERIM.
                # 5: DISEÑO
                # 6: VACIADO
                # 7: CLIENTE
                # 8: FECHA
                # 9: V. SALIDA
                # 10: UBICACIÓN
                # 11: OPERADOR
                # 12: MIXER
                # 13: ELEMENTO
                # 14: REGULACION
                # 15: N° DE ROTURAS
                # 16: ACELERANTE
                # 17: F. ROTURA (ACELERANTE)
                # 18: F. ROTURA (3D)
                # 19: F. ROTURA (7D)
                # 20: F. ROTURA (14D)
                # 21: F. ROTURA (28D)
                
                orden_carguio = escape_sql(row[2])
                n_carguio = parse_int(row[3])
                requerimiento = escape_sql(row[4])
                diseno = escape_sql(row[5])
                vaciado = escape_sql(row[6])
                cliente = escape_sql(row[7])
                fecha = parse_date(row[8])
                v_salida = parse_num(row[9])
                ubicacion = escape_sql(row[10])
                operador = escape_sql(row[11])
                mixer = escape_sql(row[12])
                elemento = escape_sql(row[13])
                regulacion = escape_sql(row[14])
                n_roturas = escape_sql(row[15])
                acelerante = escape_sql(row[16])
                f_rot_ace = parse_date(row[17])
                f_rot_3d = parse_date(row[18])
                f_rot_7d = parse_date(row[19])
                f_rot_14d = parse_date(row[20])
                f_rot_28d = parse_date(row[21])
                
                sql = f"INSERT INTO muestras_laboratorio (codigo_laboratorio, orden_carguio, n_carguio, requerimiento, diseno, vaciado, cliente, fecha, v_salida, ubicacion, operador, mixer, elemento, regulacion, n_roturas, acelerante, f_rotura_acelerante, f_rotura_3d, f_rotura_7d, f_rotura_14d, f_rotura_28d) VALUES ({escape_sql(codigo)}, {orden_carguio}, {n_carguio}, {requerimiento}, {diseno}, {vaciado}, {cliente}, {fecha}, {v_salida}, {ubicacion}, {operador}, {mixer}, {elemento}, {regulacion}, {n_roturas}, {acelerante}, {f_rot_ace}, {f_rot_3d}, {f_rot_7d}, {f_rot_14d}, {f_rot_28d});\n"
                out.write(sql)
            
            out.write("COMMIT;\n")
    print("Script completado: insert_laboratorio.sql generado.")
except Exception as e:
    print(f"Error: {e}")
