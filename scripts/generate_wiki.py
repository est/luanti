#!/usr/bin/env python3
"""
generate_wiki.py
Reads captured JSON data and generates VitePress Markdown wiki pages.
"""

import json
import os
import sys

INPUT_FILE = sys.argv[1] if len(sys.argv) > 1 else "scripts/output.json"
WIKI_DIR = sys.argv[2] if len(sys.argv) > 2 else "wiki"


def load_data(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def clean_description(desc):
    """Remove translation function wrappers."""
    if not desc:
        return ""
    return str(desc).strip()


def format_groups(groups):
    """Format groups dict as readable string."""
    if not groups or not isinstance(groups, dict):
        return ""
    parts = []
    for k, v in sorted(groups.items()):
        if k.startswith("not_in_") or k.startswith("pathfinder"):
            continue
        parts.append(f"{k}={v}")
    return ", ".join(parts)


# ============================================================================
# Generate blocks page
# ============================================================================

def generate_blocks_page(data):
    nodes = data.get("nodes", {})

    # Categorize blocks
    building = {}
    ores = {}
    nature = {}
    redstone = {}
    other = {}

    for name, node_def in sorted(nodes.items()):
        groups = node_def.get("groups", {})
        desc = clean_description(node_def.get("description", name))

        entry = {
            "name": name,
            "description": desc,
            "hardness": node_def.get("_mcl_hardness", "-"),
            "blast_resistance": node_def.get("_mcl_blast_resistance", "-"),
            "groups": format_groups(groups),
            "source_mod": node_def.get("_source_mod", ""),
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
        lines.append("| 方块 | 描述 | 硬度 | 爆炸抗性 | 来源 |")
        lines.append("|------|------|------|---------|------|")
        for name, item in list(items.items())[:100]:
            short_name = name.split(":")[-1] if ":" in name else name
            lines.append(f"| `{short_name}` | {item['description']} | {item['hardness']} | {item['blast_resistance']} | {item['source_mod']} |")
        if len(items) > 100:
            lines.append(f"\n> 显示前 100 个，共 {len(items)} 个。\n")

    return "\n".join(lines)


# ============================================================================
# Generate items page
# ============================================================================

def generate_items_page(data):
    craftitems = data.get("craftitems", {})

    lines = []
    lines.append("# 物品图鉴\n")
    lines.append(f"> 共 **{len(craftitems)}** 个物品，从 MineClonia 源码自动提取。\n")

    # Group by source mod
    by_mod = {}
    for name, item_def in sorted(craftitems.items()):
        mod = item_def.get("_source_mod", "unknown")
        if mod not in by_mod:
            by_mod[mod] = []
        by_mod[mod].append({
            "name": name,
            "description": clean_description(item_def.get("description", name)),
        })

    for mod, items in sorted(by_mod.items()):
        lines.append(f"\n## {mod} ({len(items)})\n")
        lines.append("| 物品 | 描述 |")
        lines.append("|------|------|")
        for item in items:
            short_name = item["name"].split(":")[-1] if ":" in item["name"] else item["name"]
            lines.append(f"| `{short_name}` | {item['description']} |")

    return "\n".join(lines)


# ============================================================================
# Generate tools page
# ============================================================================

def generate_tools_page(data):
    tools = data.get("tools", {})

    lines = []
    lines.append("# 工具与武器\n")
    lines.append(f"> 共 **{len(tools)}** 个工具，从 MineClonia 源码自动提取。\n")

    lines.append("| 工具 | 描述 | 来源 |")
    lines.append("|------|------|------|")
    for name, tool_def in sorted(tools.items()):
        desc = clean_description(tool_def.get("description", name))
        source = tool_def.get("_source_mod", "")
        short_name = name.split(":")[-1] if ":" in name else name
        lines.append(f"| `{short_name}` | {desc} | {source} |")

    return "\n".join(lines)


# ============================================================================
# Generate crafting recipes page
# ============================================================================

def generate_crafts_page(data):
    crafts = data.get("crafts", [])

    lines = []
    lines.append("# 合成配方\n")
    lines.append(f"> 共 **{len(crafts)}** 个配方，从 MineClonia 源码自动提取。\n")

    # Group by type
    shaped = []
    shapeless = []
    cooking = []
    fuel = []
    other = []

    for craft in crafts:
        craft_type = craft.get("type", "shaped")
        if craft_type == "shapeless":
            shapeless.append(craft)
        elif craft_type == "cooking":
            cooking.append(craft)
        elif craft_type == "fuel":
            fuel.append(craft)
        else:
            shaped.append(craft)

    # Shaped recipes
    if shaped:
        lines.append(f"\n## 有序合成 ({len(shaped)})\n")
        lines.append("| 输出 | 配方 | 来源 |")
        lines.append("|------|------|------|")
        for c in shaped[:200]:
            output = c.get("output", "?")
            recipe = c.get("recipe", [])
            recipe_str = " / ".join(
                " ".join(cell.split(":")[-1] if ":" in cell else cell for cell in row)
                for row in recipe
            ) if recipe else "?"
            source = c.get("_source_mod", "")
            lines.append(f"| `{output}` | {recipe_str} | {source} |")
        if len(shaped) > 200:
            lines.append(f"\n> 显示前 200 个，共 {len(shaped)} 个。\n")

    # Shapeless recipes
    if shapeless:
        lines.append(f"\n## 无序合成 ({len(shapeless)})\n")
        lines.append("| 输出 | 材料 | 来源 |")
        lines.append("|------|------|------|")
        for c in shapeless[:100]:
            output = c.get("output", "?")
            recipe = c.get("recipe", [])
            recipe_str = ", ".join(r.split(":")[-1] if ":" in r else r for r in recipe)
            source = c.get("_source_mod", "")
            lines.append(f"| `{output}` | {recipe_str} | {source} |")

    # Cooking recipes
    if cooking:
        lines.append(f"\n## 烧炼 ({len(cooking)})\n")
        lines.append("| 输入 | 输出 | 来源 |")
        lines.append("|------|------|------|")
        for c in cooking[:100]:
            recipe = c.get("recipe", [])
            output = c.get("output", "?")
            input_str = recipe[0].split(":")[-1] if recipe and ":" in recipe[0] else (recipe[0] if recipe else "?")
            source = c.get("_source_mod", "")
            lines.append(f"| `{input_str}` | `{output}` | {source} |")

    return "\n".join(lines)


# ============================================================================
# Main
# ============================================================================

def main():
    print(f"Loading data from {INPUT_FILE}...")
    data = load_data(INPUT_FILE)

    print(f"Generating wiki pages to {WIKI_DIR}/...")

    # Ensure output directories exist
    os.makedirs(os.path.join(WIKI_DIR, "items"), exist_ok=True)
    os.makedirs(os.path.join(WIKI_DIR, "recipes"), exist_ok=True)

    # Generate pages
    pages = {
        "items/blocks.md": generate_blocks_page(data),
        "items/items.md": generate_items_page(data),
        "items/tools.md": generate_tools_page(data),
        "recipes/crafting.md": generate_crafts_page(data),
    }

    for path, content in pages.items():
        full_path = os.path.join(WIKI_DIR, path)
        with open(full_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  Written: {full_path} ({len(content)} bytes)")

    print("Done!")


if __name__ == "__main__":
    main()
