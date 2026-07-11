#!/usr/bin/env python3
"""
generate_wiki.py
Reads captured JSON data + translations and generates VitePress Markdown wiki pages.
Usage: python3 scripts/generate_wiki.py [output.json] [wiki_dir] [translations.json]
"""

import json
import os
import sys

INPUT_FILE = sys.argv[1] if len(sys.argv) > 1 else "scripts/output.json"
WIKI_DIR = sys.argv[2] if len(sys.argv) > 2 else "wiki"
TRANSLATIONS_FILE = sys.argv[3] if len(sys.argv) > 3 else "scripts/translations.json"

CODEBERG_RAW = "https://codeberg.org/mineclonia/mineclonia/raw/branch/main"


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def clean_description(desc):
    if not desc:
        return ""
    return str(desc).strip()


def translate(text, trans_map):
    """Look up Chinese translation for an English text."""
    if not text or not trans_map:
        return ""
    return trans_map.get(text, "")


def item_id_to_zh(item_id, data, trans_map):
    """Look up Chinese translation for an item ID by finding its description first."""
    if not item_id or not trans_map:
        return ""
    # Clean item ID (remove count suffix like " 4")
    clean_id = item_id.split(" ")[0]
    # Look up in all registered items
    desc = None
    for table in ["nodes", "craftitems", "tools"]:
        item_def = data.get(table, {}).get(clean_id)
        if item_def:
            desc = clean_description(item_def.get("description", ""))
            break
    if desc:
        return translate(desc, trans_map)
    return ""


def extract_texture(defn):
    """Extract first texture filename from a node/item definition."""
    tiles = defn.get("tiles") or defn.get("inventory_image") or defn.get("wield_image") or ""
    if isinstance(tiles, str):
        # inventory_image might be "mod_name.png" or "mod_name.png^[..."
        tex = tiles.split("^")[0].split("[")[0].strip()
        return tex if tex.endswith(".png") else ""
    if isinstance(tiles, list) and tiles:
        first = tiles[0]
        if isinstance(first, str):
            return first.split("^")[0].split("[")[0].strip()
        if isinstance(first, dict):
            return first.get("name", "").split("^")[0].strip()
    return ""


def texture_url(texture_name, mod_name):
    """Construct Codeberg raw URL for a texture file."""
    if not texture_name:
        return ""
    return f"{CODEBERG_RAW}/mods/ITEMS/{mod_name}/textures/{texture_name}"


def texture_url_any(texture_name, mod_name):
    """Try common mod paths for texture."""
    if not texture_name:
        return ""
    # Most items are in ITEMS/, some in CORE/, ENTITIES/, etc.
    for prefix in ["ITEMS", "CORE", "ENTITIES", "PLAYER", "HUD"]:
        url = f"{CODEBERG_RAW}/mods/{prefix}/{mod_name}/textures/{texture_name}"
        return url  # Just return the first guess; items are mostly in ITEMS/
    return f"{CODEBERG_RAW}/mods/ITEMS/{mod_name}/textures/{texture_name}"


def img_hover(texture_name, mod_name, alt=""):
    """Generate an inline image with hover preview."""
    url = texture_url_any(texture_name, mod_name)
    if not url:
        return ""
    return f'<img src="{url}" alt="{alt}" width="24" height="24" style="vertical-align:middle;cursor:help" onerror="this.style.display=\'none\'" />'


def format_groups(groups):
    if not groups or not isinstance(groups, dict):
        return ""
    parts = []
    for k, v in sorted(groups.items()):
        if k.startswith("not_in_") or k.startswith("pathfinder"):
            continue
        parts.append(f"{k}={v}")
    return ", ".join(parts)


# ============================================================================
# Block table row helper
# ============================================================================

def block_row(name, item, trans_map):
    short_name = name.split(":")[-1] if ":" in name else name
    desc = item["description"]
    if desc.startswith(":") or desc == short_name:
        desc = "-"
    zh = translate(desc, trans_map)
    tex = item.get("texture", "")
    mod = item.get("source_mod", "")
    img = img_hover(tex, mod, short_name)
    icon_col = f" {img}" if img else ""
    return f"|{icon_col} `{short_name}` | {desc} | {zh} | {item['hardness']} | {item['blast_resistance']} | {item['source_mod']} |"


# ============================================================================
# Generate blocks page
# ============================================================================

def generate_blocks_page(data, trans_map):
    nodes = data.get("nodes", {})

    building, ores, nature, redstone, other = {}, {}, {}, {}, {}

    for name, node_def in sorted(nodes.items()):
        groups = node_def.get("groups", {})
        desc = clean_description(node_def.get("description", name))
        tex = extract_texture(node_def)
        mod = node_def.get("_source_mod", "")

        entry = {
            "name": name, "description": desc,
            "hardness": node_def.get("_mcl_hardness", "-"),
            "blast_resistance": node_def.get("_mcl_blast_resistance", "-"),
            "groups": format_groups(groups),
            "source_mod": mod, "texture": tex,
        }

        if "ore" in name or "ore" in groups:
            ores[name] = entry
        elif any(g in groups for g in ["building_block", "deco_block", "material_stone", "material_wood"]):
            building[name] = entry
        elif any(g in groups for g in ["plant", "flower", "sapling", "leaves", "tree"]):
            nature[name] = entry
        elif any(g in groups for g in ["mesecon", "redstone"]):
            redstone[name] = entry
        else:
            other[name] = entry

    lines = []
    lines.append("# 方块图鉴\n")
    lines.append(f"> 共 **{len(nodes)}** 个方块，从 MineClonia 源码自动提取。\n")

    for category, items in [
        ("建筑方块", building), ("矿石", ores), ("自然方块", nature),
        ("红石/Mesecons", redstone), ("其他", other)
    ]:
        if not items:
            continue
        lines.append(f"\n## {category} ({len(items)})\n")
        lines.append("|  | 方块 | 中文 | 硬度 | 爆炸抗性 | 来源 |")
        lines.append("|:-:|:-----|:-----|-----:|---------:|:-----|")
        for name, item in list(items.items())[:100]:
            lines.append(block_row(name, item, trans_map))
        if len(items) > 100:
            lines.append(f"\n> 显示前 100 个，共 {len(items)} 个。\n")

    return "\n".join(lines)


# ============================================================================
# Generate items page
# ============================================================================

def generate_items_page(data, trans_map):
    craftitems = data.get("craftitems", {})

    lines = []
    lines.append("# 物品图鉴\n")
    lines.append(f"> 共 **{len(craftitems)}** 个物品，从 MineClonia 源码自动提取。\n")

    by_mod = {}
    for name, item_def in sorted(craftitems.items()):
        mod = item_def.get("_source_mod", "unknown")
        if mod not in by_mod:
            by_mod[mod] = []
        desc = clean_description(item_def.get("description", name))
        tex = extract_texture(item_def)
        by_mod[mod].append({"name": name, "description": desc, "texture": tex})

    for mod, items in sorted(by_mod.items()):
        lines.append(f"\n## {mod} ({len(items)})\n")
        lines.append("|  | 物品 | 中文 |")
        lines.append("|:-:|:-----|:-----|")
        for item in items:
            short_name = item["name"].split(":")[-1] if ":" in item["name"] else item["name"]
            zh = translate(item["description"], trans_map)
            img = img_hover(item["texture"], mod, short_name)
            icon_col = f" {img}" if img else ""
            lines.append(f"|{icon_col} `{short_name}` | {item['description']} | {zh} |")

    return "\n".join(lines)


# ============================================================================
# Generate tools page
# ============================================================================

def generate_tools_page(data, trans_map):
    tools = data.get("tools", {})

    lines = []
    lines.append("# 工具与武器\n")
    lines.append(f"> 共 **{len(tools)}** 个工具，从 MineClonia 源码自动提取。\n")

    lines.append("|  | 工具 | 中文 | 来源 |")
    lines.append("|:-:|:-----|:-----|:-----|")
    for name, tool_def in sorted(tools.items()):
        desc = clean_description(tool_def.get("description", name))
        zh = translate(desc, trans_map)
        source = tool_def.get("_source_mod", "")
        short_name = name.split(":")[-1] if ":" in name else name
        tex = extract_texture(tool_def)
        img = img_hover(tex, source, short_name)
        icon_col = f" {img}" if img else ""
        lines.append(f"|{icon_col} `{short_name}` | {desc} | {zh} | {source} |")

    return "\n".join(lines)


# ============================================================================
# Generate crafting recipes page
# ============================================================================

def generate_crafts_page(data, trans_map):
    crafts = data.get("crafts", [])

    lines = []
    lines.append("# 合成配方\n")
    lines.append(f"> 共 **{len(crafts)}** 个配方，从 MineClonia 源码自动提取。\n")

    shaped, shapeless, cooking, fuel, other = [], [], [], [], []

    for craft in crafts:
        t = craft.get("type", "shaped")
        if t == "shapeless":
            shapeless.append(craft)
        elif t == "cooking":
            cooking.append(craft)
        elif t == "fuel":
            fuel.append(craft)
        else:
            shaped.append(craft)

    if shaped:
        lines.append(f"\n## 有序合成 ({len(shaped)})\n")
        lines.append("| 输出 | 中文 | 配方 | 来源 |")
        lines.append("|:-----|:-----|:-----|:-----|")
        for c in shaped[:200]:
            output = c.get("output", "?")
            recipe = c.get("recipe", [])
            recipe_str = " / ".join(
                " ".join(cell.split(":")[-1] if ":" in cell else cell for cell in row)
                for row in recipe
            ) if recipe else "?"
            zh = item_id_to_zh(output, data, trans_map)
            source = c.get("_source_mod", "")
            lines.append(f"| `{output}` | {zh} | {recipe_str} | {source} |")
        if len(shaped) > 200:
            lines.append(f"\n> 显示前 200 个，共 {len(shaped)} 个。\n")

    if shapeless:
        lines.append(f"\n## 无序合成 ({len(shapeless)})\n")
        lines.append("| 输出 | 中文 | 材料 | 来源 |")
        lines.append("|:-----|:-----|:-----|:-----|")
        for c in shapeless[:100]:
            output = c.get("output", "?")
            recipe = c.get("recipe", [])
            recipe_str = ", ".join(r.split(":")[-1] if ":" in r else r for r in recipe)
            zh = item_id_to_zh(output, data, trans_map)
            source = c.get("_source_mod", "")
            lines.append(f"| `{output}` | {zh} | {recipe_str} | {source} |")

    if cooking:
        lines.append(f"\n## 烧炼 ({len(cooking)})\n")
        lines.append("| 输入 | 输出 | 中文 | 来源 |")
        lines.append("|:-----|:-----|:-----|:-----|")
        for c in cooking[:100]:
            recipe = c.get("recipe", [])
            output = c.get("output", "?")
            input_str = recipe[0].split(":")[-1] if recipe and ":" in recipe[0] else (recipe[0] if recipe else "?")
            zh = item_id_to_zh(output, data, trans_map)
            source = c.get("_source_mod", "")
            lines.append(f"| `{input_str}` | `{output}` | {zh} | {source} |")

    return "\n".join(lines)


# ============================================================================
# Main
# ============================================================================

def main():
    print(f"Loading data from {INPUT_FILE}...")
    data = load_json(INPUT_FILE)

    trans_map = {}
    if os.path.exists(TRANSLATIONS_FILE):
        print(f"Loading translations from {TRANSLATIONS_FILE}...")
        trans_map = load_json(TRANSLATIONS_FILE)
        print(f"  {len(trans_map)} translations loaded")
    else:
        print(f"Translations file not found, skipping Chinese column")

    print(f"Generating wiki pages to {WIKI_DIR}/...")

    os.makedirs(os.path.join(WIKI_DIR, "items"), exist_ok=True)
    os.makedirs(os.path.join(WIKI_DIR, "recipes"), exist_ok=True)

    pages = {
        "items/blocks.md": generate_blocks_page(data, trans_map),
        "items/items.md": generate_items_page(data, trans_map),
        "items/tools.md": generate_tools_page(data, trans_map),
        "recipes/crafting.md": generate_crafts_page(data, trans_map),
    }

    for path, content in pages.items():
        full_path = os.path.join(WIKI_DIR, path)
        with open(full_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  Written: {full_path} ({len(content)} bytes)")

    print("Done!")


if __name__ == "__main__":
    main()
