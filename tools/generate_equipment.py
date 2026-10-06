"""Build Rojo-ready Tools from the local starter GLBs, without uploaded mesh IDs.

Roblox cannot reference a local FBX/GLB as a MeshPart. These source Tools use
native cylinders and wedge geometry following the exported meshes. Very small
bevels are simplified. Original FBX/GLB files remain the high-detail mesh source.
"""
from pathlib import Path
import json
import math
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "equipment"
SOURCE = ROOT / "assets" / "starter-weapons"
SCALE = 0.85
counter = 0


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, n): return tuple(x * n for x in a)
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a, a))
def unit(a): return mul(a, 1 / length(a))


def prop(parent, kind, name, value):
    entry = ET.SubElement(parent, kind, name=name)
    if isinstance(value, dict):
        for key, child in value.items(): ET.SubElement(entry, key).text = str(child)
    else: entry.text = str(value).lower() if isinstance(value, bool) else str(value)
    return entry


def item(parent, class_name, name):
    global counter
    counter += 1
    result = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX_{counter}"})
    properties = ET.SubElement(result, "Properties")
    prop(properties, "string", "Name", name)
    return result, properties


def cframe(properties, name, position, right=(1,0,0), up=(0,1,0), back=(0,0,1)):
    fields = dict(zip(("X", "Y", "Z"), position))
    for row in range(3):
        for col, axis in enumerate((right, up, back)): fields[f"R{row}{col}"] = axis[row]
    prop(properties, "CoordinateFrame", name, fields)


def part(parent, name, size, position, color, material=1088, shape=1, basis=None, class_name="Part", transparency=0):
    result, properties = item(parent, class_name, name)
    prop(properties, "Vector3", "size", dict(zip(("X", "Y", "Z"), (max(0.001, s) for s in size))))
    cframe(properties, "CFrame", position, *(basis or ((1,0,0),(0,1,0),(0,0,1))))
    prop(properties, "Color3uint8", "Color3uint8", 0xFF000000 | (color[0]<<16) | (color[1]<<8) | color[2])
    for key, value in {"Anchored": False, "CanCollide": False, "CanTouch": False, "CanQuery": False, "Massless": True}.items(): prop(properties, "bool", key, value)
    prop(properties, "float", "Transparency", transparency)
    prop(properties, "token", "Material", material)
    if class_name == "Part": prop(properties, "token", "shape", shape)
    for key in ("TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"): prop(properties, "token", key, 0)
    return result


def weld(piece, handle):
    _, properties = item(piece, "WeldConstraint", "HandleWeld")
    prop(properties, "Ref", "Part0", handle.attrib["referent"])
    prop(properties, "Ref", "Part1", piece.attrib["referent"])


def triangle(parent, handle, a, b, c, thickness, color, material, name):
    ab, ac, bc = sub(b,a), sub(c,a), sub(c,b)
    if dot(ab,ab) > dot(ac,ac) and dot(ab,ab) > dot(bc,bc): c, a = a, c
    elif dot(ac,ac) > dot(bc,bc) and dot(ac,ac) > dot(ab,ab): a, b = b, a
    ab, ac, bc = sub(b,a), sub(c,a), sub(c,b)
    normal = cross(ac, ab)
    if length(normal) < 0.000001 or length(bc) < 0.000001: return
    right = unit(normal)
    back = unit(bc)
    up = unit(cross(back, right))
    height = abs(dot(ab, up))
    for index, (endpoint, side, forward, width) in enumerate(((b,right,back,abs(dot(ab,back))), (c,mul(right,-1),mul(back,-1),abs(dot(ac,back))))):
        if width < 0.001 or height < 0.001: continue
        piece = part(parent, name + f"_{index}", (thickness, height, width), mul(add(a,endpoint),0.5), color, material, basis=(side,up,forward), class_name="WedgePart")
        weld(piece, handle)


def identity(): return [[1 if r==c else 0 for c in range(4)] for r in range(4)]
def matrix_product(a,b): return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]
def transform(matrix, point): return tuple(sum(matrix[r][c]*point[c] for c in range(3)) + matrix[r][3] for r in range(3))


def node_matrix(node):
    if "matrix" in node: return [[node["matrix"][c*4+r] for c in range(4)] for r in range(4)]
    x,y,z,w = node.get("rotation", (0,0,0,1))
    scale = node.get("scale", (1,1,1))
    m = [[1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w, 0], [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w,0], [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y,0], [0,0,0,1]]
    for r in range(3):
        for c in range(3): m[r][c] *= scale[c]
        m[r][3] = node.get("translation", (0,0,0))[r]
    return m


def load_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b"glTF"
    json_size, _ = struct.unpack_from("<II", raw, 12)
    data = json.loads(raw[20:20+json_size])
    bin_start = 20 + json_size
    bin_size, _ = struct.unpack_from("<II", raw, bin_start)
    buffer = raw[bin_start+8:bin_start+8+bin_size]
    def read(index):
        accessor = data["accessors"][index]
        view = data["bufferViews"][accessor["bufferView"]]
        code = {5126:"f",5125:"I",5123:"H",5121:"B"}[accessor["componentType"]]
        count = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[accessor["type"]]
        format_ = "<" + code*count
        stride = view.get("byteStride", struct.calcsize(format_))
        offset = view.get("byteOffset",0) + accessor.get("byteOffset",0)
        values = [struct.unpack_from(format_, buffer, offset+i*stride) for i in range(accessor["count"])]
        return [v[0] for v in values] if count==1 else values
    return data, read


def cylinder_between(parent, handle, a, b, radius, color, material, name):
    delta = sub(b,a)
    if length(delta)<0.001: return
    right = unit(delta)
    reference = (0,0,1) if abs(right[2])<0.95 else (1,0,0)
    up = unit(sub(reference, mul(right,dot(reference,right))))
    back = cross(right,up)
    piece = part(parent, name, (length(delta),radius*2,radius*2), mul(add(a,b),0.5), color, material, shape=2, basis=(right,up,back))
    weld(piece,handle)


def radial_rings(vertices):
    unique = {tuple(round(v,5) for v in p) for p in vertices}
    groups = {}
    for x,y,z in unique: groups.setdefault(y,[]).append((x,y,z))
    if len(groups)<2: return None
    rings=[]
    for y, points in sorted(groups.items()):
        if len(points)<8: return None
        center=(sum(p[0] for p in points)/len(points),y,sum(p[2] for p in points)/len(points))
        radii=[length(sub(p,center)) for p in points]
        if max(radii)-min(radii)>0.003: return None
        rings.append((center,sum(radii)/len(radii)))
    return rings


def components(vertices, indices):
    keys=[tuple(round(v,5) for v in p) for p in vertices]
    neighbors={key:set() for key in keys}
    for i in range(0,len(indices),3):
        a,b,c=(keys[index] for index in indices[i:i+3])
        neighbors[a].update((b,c)); neighbors[b].update((a,c)); neighbors[c].update((a,b))
    seen=set(); result=[]
    for key in neighbors:
        if key in seen: continue
        pending=[key]; group=[]; seen.add(key)
        while pending:
            current=pending.pop(); group.append(current)
            for other in neighbors[current]:
                if other not in seen: seen.add(other); pending.append(other)
        result.append(group)
    return result


def build_weapon(source_name, asset_name, display_name):
    data, read = load_glb(SOURCE / source_name)
    xml = ET.Element("roblox", version="4")
    ET.SubElement(xml,"External").text="null"; ET.SubElement(xml,"External").text="nil"
    tool, properties = item(xml,"Tool",display_name)
    for key,value in {"RequiresHandle":True,"CanBeDropped":False,"ManualActivationOnly":True,"Enabled":True}.items(): prop(properties,"bool",key,value)
    prop(properties,"string","ToolTip",display_name + " · Equip through the Gear menu")
    cframe(properties,"Grip",(0,0,0))
    handle = part(tool,"Handle",(0.18,0.18,0.18),(0,0,0),(99,72,48),512,transparency=1)
    def visit(index, parent_matrix):
        node=data["nodes"][index]
        matrix=matrix_product(parent_matrix,node_matrix(node))
        if "mesh" in node:
            for primitive in data["meshes"][node["mesh"]]["primitives"]:
                vertices=read(primitive["attributes"]["POSITION"]); indices=read(primitive["indices"])
                material_data=data["materials"][primitive.get("material",0)]
                rgb=material_data.get("pbrMetallicRoughness",{}).get("baseColorFactor",[0.5,0.5,0.5,1])[:3]
                # GLTF colors are linear; Roblox part colors are displayed in sRGB.
                color=tuple(round((12.92*v if v<=0.0031308 else 1.055*v**(1/2.4)-0.055)*255) for v in rgb)
                material_name=material_data.get("name","").lower()
                material=512 if "wood" in material_name else 2309 if "leather" in material_name else 1312 if "linen" in material_name else 272 if "stone" in material_name or "crystal" in material_name else 1088
                name=node.get("name",asset_name)
                groups=components(vertices,indices) if "binding" in name else [vertices]
                rings=[radial_rings(group) for group in groups]
                if "binding" in name:
                    for group_index, group in enumerate(groups):
                        low=tuple(min(p[k] for p in group) for k in range(3))
                        high=tuple(max(p[k] for p in group) for k in range(3))
                        center=mul(add(low,high),0.5)
                        a=(center[0],low[1],center[2]); b=(center[0],high[1],center[2])
                        radius=max(high[0]-low[0],high[2]-low[2])*0.5*SCALE
                        cylinder_between(tool,handle,mul(transform(matrix,a),SCALE),mul(transform(matrix,b),SCALE),radius,color,material,name+f"_{group_index}")
                elif "rivet" in name:
                    low=tuple(min(p[k] for p in vertices) for k in range(3)); high=tuple(max(p[k] for p in vertices) for k in range(3))
                    center=transform(matrix,mul(add(low,high),0.5))
                    axes=[tuple(matrix[r][c] for r in range(3)) for c in range(3)]
                    size=tuple((high[c]-low[c])*length(axes[c])*SCALE for c in range(3))
                    piece=part(tool,name,size,mul(center,SCALE),color,material,shape=0,basis=tuple(unit(a) for a in axes))
                    weld(piece,handle)
                elif all(rings):
                    for group_index, ring in enumerate(rings):
                        for section in range(len(ring)-1):
                            a,ra=ring[section]; b,rb=ring[section+1]
                            cylinder_between(tool,handle,mul(transform(matrix,a),SCALE),mul(transform(matrix,b),SCALE),(ra+rb)*0.5*SCALE,color,material,f"{name}_{group_index}_{section}")
                else:
                    flat=any(word in name for word in ("flange", "fork", "halo", "crossguard", "blade", "rain guard", "mount"))
                    zmin=min(v[2] for v in vertices); zmax=max(v[2] for v in vertices)
                    for i in range(0,len(indices),3):
                        a,b,c=(vertices[j] for j in indices[i:i+3])
                        if flat:
                            # Front-facing projected triangles retain holes and concave
                            # outlines; extrude through the component's thickness.
                            if cross(sub(b,a),sub(c,a))[2]<=0.000001: continue
                            z=(zmin+zmax)*0.5
                            a,b,c=((p[0],p[1],z) for p in (a,b,c))
                        points=[mul(transform(matrix,p),SCALE) for p in (a,b,c)]
                        thickness=(zmax-zmin)*SCALE if flat else 0.008
                        triangle(tool,handle,*points,max(thickness,0.008),color,material,name+f"_{i//3}")
        for child in node.get("children",[]): visit(child,matrix)
    for index in data["scenes"][data.get("scene",0)]["nodes"]: visit(index,identity())
    path=OUTPUT / "weapons" / (asset_name+".rbxmx")
    path.parent.mkdir(parents=True,exist_ok=True); ET.indent(xml)
    ET.ElementTree(xml).write(path,encoding="utf-8",xml_declaration=True)
    print(f"{asset_name}: {len(xml.findall('.//Item[@class=\"Part\"]')) + len(xml.findall('.//Item[@class=\"WedgePart\"]'))} parts")


def build_armor(asset_name, color):
    xml=ET.Element("roblox",version="4")
    model,properties=item(xml,"Model",asset_name)
    armor=part(model,"MarchArmor",(2.12,1.24,1.12),(0,-0.02,-0.02),color)
    prop(properties,"Ref","PrimaryPart",armor.attrib["referent"])
    part(model,"ArmorBelt",(2.17,0.26,1.18),(0,-0.74,-0.025),(91,61,39),2309)
    for side in (-1,1): part(model,"ShoulderGuard",(0.8,0.45,1.18),(side*0.96,0.78,0),color)
    path=OUTPUT / "armor" / (asset_name+".rbxmx")
    path.parent.mkdir(parents=True,exist_ok=True); ET.indent(xml)
    ET.ElementTree(xml).write(path,encoding="utf-8",xml_declaration=True)


def build_shield():
    xml=ET.Element("roblox",version="4")
    model,properties=item(xml,"Model","WardenShield")
    shield=part(model,"WardenShield",(1.4,1.8,0.25),(0,-0.15,-0.55),(105,119,127))
    prop(properties,"Ref","PrimaryPart",shield.attrib["referent"])
    path=OUTPUT / "offhands" / "WardenShield.rbxmx"
    path.parent.mkdir(parents=True,exist_ok=True); ET.indent(xml)
    ET.ElementTree(xml).write(path,encoding="utf-8",xml_declaration=True)


if __name__=="__main__":
    for source,asset,name in (("Crownless_Iron_Mace.glb","IronMace","Iron Mace"),("Crownless_Acolyte_Scepter.glb","AcolyteScepter","Acolyte Scepter"),("Crownless_Iron_Sword.glb","IronSword","Iron Sword"),("Crownless_Apprentice_Staff.glb","ApprenticeStaff","Apprentice Staff")):
        build_weapon(source,asset,name)
    for asset,color in (("MarchWardenPlate",(105,119,127)),("FieldMedicLeathers",(107,135,95)),("RoadwornBrigandine",(153,84,61)),("MarchSurveyorCoat",(124,105,151))): build_armor(asset,color)
    build_shield()
