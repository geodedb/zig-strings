#!/usr/bin/env python3
"""
Unicode Character Database (UCD) Table Generator

Downloads UCD data files and generates Zig source code with lookup tables for:
- Canonical Combining Class (CCC)
- Decomposition mappings
- Composition mappings (for NFC)

Uses two-stage tables for efficient O(1) lookup with good compression.
"""

import os
import sys
import urllib.request
from collections import defaultdict
from typing import Dict, List, Tuple, Optional, Set

UNICODE_VERSION = "15.1.0"
UCD_BASE_URL = f"https://www.unicode.org/Public/{UNICODE_VERSION}/ucd/"

# Cache directory for downloaded files
CACHE_DIR = os.path.join(os.path.dirname(__file__), ".ucd_cache")


def download_file(filename: str) -> str:
    """Download a UCD file if not cached."""
    cache_path = os.path.join(CACHE_DIR, filename)
    cache_dir = os.path.dirname(cache_path)
    os.makedirs(cache_dir, exist_ok=True)

    if os.path.exists(cache_path):
        print(f"Using cached {filename}")
        with open(cache_path, 'r', encoding='utf-8') as f:
            return f.read()

    url = UCD_BASE_URL + filename
    print(f"Downloading {url}...")
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read().decode('utf-8')
        with open(cache_path, 'w', encoding='utf-8') as f:
            f.write(data)
        return data
    except Exception as e:
        print(f"Error downloading {filename}: {e}")
        sys.exit(1)


def parse_unicode_data(data: str) -> Dict[int, dict]:
    """Parse UnicodeData.txt into a dictionary keyed by code point."""
    entries = {}

    for line in data.strip().split('\n'):
        if not line or line.startswith('#'):
            continue

        fields = line.split(';')
        if len(fields) < 15:
            continue

        cp = int(fields[0], 16)
        name = fields[1]
        category = fields[2]
        ccc = int(fields[3]) if fields[3] else 0
        decomp = fields[5]

        # Parse decomposition
        decomp_type = None
        decomp_mapping = []
        if decomp:
            if decomp.startswith('<'):
                # Compatibility decomposition
                end = decomp.index('>')
                decomp_type = decomp[1:end]
                decomp = decomp[end+1:].strip()
            if decomp:
                decomp_mapping = [int(x, 16) for x in decomp.split()]

        entries[cp] = {
            'name': name,
            'category': category,
            'ccc': ccc,
            'decomp_type': decomp_type,  # None = canonical, else compatibility
            'decomp_mapping': decomp_mapping,
        }

        # Handle ranges (e.g., CJK Ideographs)
        if name.endswith(', First>'):
            range_start = cp
        elif name.endswith(', Last>'):
            # Fill in the range with the same properties (except name)
            for range_cp in range(range_start + 1, cp):
                entries[range_cp] = {
                    'name': f"<range {hex(range_cp)}>",
                    'category': category,
                    'ccc': ccc,
                    'decomp_type': None,
                    'decomp_mapping': [],
                }

    return entries


def parse_composition_exclusions(data: str) -> Set[int]:
    """Parse CompositionExclusions.txt."""
    exclusions = set()

    for line in data.strip().split('\n'):
        line = line.split('#')[0].strip()
        if not line:
            continue

        if '..' in line:
            start, end = line.split('..')
            for cp in range(int(start, 16), int(end, 16) + 1):
                exclusions.add(cp)
        else:
            exclusions.add(int(line, 16))

    return exclusions


def build_ccc_table(entries: Dict[int, dict]) -> Tuple[List[int], List[int]]:
    """Build two-stage CCC table.

    Returns (stage1, stage2) where:
    - stage1[block] = index into stage2
    - stage2[stage1[block] + (cp & 0xFF)] = CCC value
    """
    BLOCK_SIZE = 256
    MAX_CODEPOINT = 0x10FFFF

    # Group code points by block
    blocks = defaultdict(lambda: [0] * BLOCK_SIZE)

    for cp, entry in entries.items():
        if cp > MAX_CODEPOINT:
            continue
        block_idx = cp >> 8
        offset = cp & 0xFF
        blocks[block_idx][offset] = entry['ccc']

    # Deduplicate blocks
    stage1 = []
    stage2 = []
    block_to_index = {}

    for block_idx in range((MAX_CODEPOINT >> 8) + 1):
        block_data = tuple(blocks[block_idx])

        if block_data in block_to_index:
            stage1.append(block_to_index[block_data])
        else:
            index = len(stage2)
            block_to_index[block_data] = index
            stage1.append(index)
            stage2.extend(block_data)

    return stage1, stage2


def build_decomposition_table(entries: Dict[int, dict]) -> Dict[int, List[int]]:
    """Build canonical decomposition mapping table.

    Only includes canonical decompositions (not compatibility).
    """
    decompositions = {}

    for cp, entry in entries.items():
        if entry['decomp_mapping'] and entry['decomp_type'] is None:
            # Canonical decomposition
            decompositions[cp] = entry['decomp_mapping']

    # Add Hangul syllable decomposition is handled algorithmically
    # (no need to store in table)

    return decompositions


def build_composition_table(entries: Dict[int, dict], exclusions: Set[int]) -> List[Tuple[int, int, int]]:
    """Build canonical composition mapping table.

    Returns list of (starter, combiner, composite) tuples.
    Excludes composition exclusions per UAX #15.
    """
    compositions = []

    for cp, entry in entries.items():
        # Only consider canonical decompositions of length 2
        if entry['decomp_type'] is not None:
            continue  # Skip compatibility decompositions

        mapping = entry['decomp_mapping']
        if len(mapping) != 2:
            continue

        starter, combiner = mapping

        # Check composition exclusions
        if cp in exclusions:
            continue

        # The starter must be a starter (CCC = 0)
        if starter in entries and entries[starter]['ccc'] != 0:
            continue

        compositions.append((starter, combiner, cp))

    # Sort for efficient lookup
    compositions.sort()

    return compositions


def generate_zig_ccc_table(stage1: List[int], stage2: List[int]) -> str:
    """Generate Zig source for CCC lookup table."""
    lines = []
    lines.append("//! Generated Unicode Canonical Combining Class table")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")
    lines.append("/// Canonical Combining Class type")
    lines.append("pub const CombiningClass = u8;")
    lines.append("")

    # Stage 1 table
    lines.append(f"/// Stage 1 index table ({len(stage1)} blocks)")
    lines.append("const ccc_stage1 = [_]u16{")
    for i in range(0, len(stage1), 16):
        chunk = stage1[i:i+16]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Stage 2 table
    lines.append(f"/// Stage 2 data table ({len(stage2)} entries)")
    lines.append("const ccc_stage2 = [_]u8{")
    for i in range(0, len(stage2), 32):
        chunk = stage2[i:i+32]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Lookup function
    lines.append("/// Gets the Canonical Combining Class for a code point")
    lines.append("pub fn getCombiningClass(cp: Codepoint) CombiningClass {")
    lines.append("    if (cp > 0x10FFFF) return 0;")
    lines.append("    const block = @as(usize, cp >> 8);")
    lines.append("    if (block >= ccc_stage1.len) return 0;")
    lines.append("    const offset = @as(usize, cp & 0xFF);")
    lines.append("    const stage2_idx = ccc_stage1[block] + offset;")
    lines.append("    if (stage2_idx >= ccc_stage2.len) return 0;")
    lines.append("    return ccc_stage2[stage2_idx];")
    lines.append("}")
    lines.append("")
    lines.append("/// Checks if a code point is a starter (CCC = 0)")
    lines.append("pub fn isStarter(cp: Codepoint) bool {")
    lines.append("    return getCombiningClass(cp) == 0;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def generate_zig_decomposition_table(decompositions: Dict[int, List[int]]) -> str:
    """Generate Zig source for decomposition lookup table."""
    lines = []
    lines.append("//! Generated Unicode Decomposition Mappings")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    # Group by decomposition length for efficiency
    by_length = defaultdict(list)
    for cp, mapping in sorted(decompositions.items()):
        by_length[len(mapping)].append((cp, mapping))

    # Generate named types for each decomposition length
    for length in sorted(by_length.keys()):
        if length == 0:
            continue
        lines.append(f"/// Entry type for decompositions of length {length}")
        lines.append(f"const DecompEntry{length} = struct {{ cp: Codepoint, decomp: [{length}]Codepoint }};")
    lines.append("")

    # Generate length-specific tables
    for length, entries in sorted(by_length.items()):
        if length == 0:
            continue
        lines.append(f"/// Decompositions of length {length} ({len(entries)} entries)")
        lines.append(f"const decomp_len{length} = [_]DecompEntry{length} {{")
        for cp, mapping in entries:
            mapping_str = ", ".join(f"0x{x:04X}" for x in mapping)
            lines.append(f"    .{{ .cp = 0x{cp:04X}, .decomp = .{{ {mapping_str} }} }},")
        lines.append("};")
        lines.append("")

    # Binary search lookup function
    lines.append("/// Gets the canonical decomposition of a code point")
    lines.append("/// Returns null if no decomposition exists")
    lines.append("pub fn getDecomposition(cp: Codepoint) ?[]const Codepoint {")
    lines.append("    // Check each length table with binary search")

    for length in sorted(by_length.keys()):
        if length == 0:
            continue
        lines.append(f"    if (binarySearchDecomp{length}(cp)) |result| {{")
        lines.append(f"        return &result.decomp;")
        lines.append("    }")

    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    # Binary search helpers
    for length in sorted(by_length.keys()):
        if length == 0:
            continue
        lines.append(f"fn binarySearchDecomp{length}(cp: Codepoint) ?*const DecompEntry{length} {{")
        lines.append(f"    var left: usize = 0;")
        lines.append(f"    var right: usize = decomp_len{length}.len;")
        lines.append(f"    while (left < right) {{")
        lines.append(f"        const mid = left + (right - left) / 2;")
        lines.append(f"        if (decomp_len{length}[mid].cp == cp) {{")
        lines.append(f"            return &decomp_len{length}[mid];")
        lines.append(f"        }} else if (decomp_len{length}[mid].cp < cp) {{")
        lines.append(f"            left = mid + 1;")
        lines.append(f"        }} else {{")
        lines.append(f"            right = mid;")
        lines.append(f"        }}")
        lines.append(f"    }}")
        lines.append(f"    return null;")
        lines.append("}")
        lines.append("")

    return "\n".join(lines)


def generate_zig_composition_table(compositions: List[Tuple[int, int, int]]) -> str:
    """Generate Zig source for composition lookup table."""
    lines = []
    lines.append("//! Generated Unicode Composition Mappings")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    lines.append(f"/// Composition pairs ({len(compositions)} entries)")
    lines.append("/// Sorted by (starter, combiner) for binary search")
    lines.append("const composition_pairs = [_]struct { starter: Codepoint, combiner: Codepoint, composite: Codepoint } {")
    for starter, combiner, composite in compositions:
        lines.append(f"    .{{ .starter = 0x{starter:04X}, .combiner = 0x{combiner:04X}, .composite = 0x{composite:04X} }},")
    lines.append("};")
    lines.append("")

    # Lookup function with binary search
    lines.append("/// Looks up a primary composite for a (starter, combiner) pair")
    lines.append("/// Returns null if no composite exists")
    lines.append("pub fn getComposite(starter: Codepoint, combiner: Codepoint) ?Codepoint {")
    lines.append("    // Check Hangul first (algorithmic composition)")
    lines.append("    if (composeHangul(starter, combiner)) |composite| {")
    lines.append("        return composite;")
    lines.append("    }")
    lines.append("")
    lines.append("    // Binary search in composition table")
    lines.append("    var left: usize = 0;")
    lines.append("    var right: usize = composition_pairs.len;")
    lines.append("    while (left < right) {")
    lines.append("        const mid = left + (right - left) / 2;")
    lines.append("        const entry = composition_pairs[mid];")
    lines.append("        if (entry.starter == starter and entry.combiner == combiner) {")
    lines.append("            return entry.composite;")
    lines.append("        } else if (entry.starter < starter or (entry.starter == starter and entry.combiner < combiner)) {")
    lines.append("            left = mid + 1;")
    lines.append("        } else {")
    lines.append("            right = mid;")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    # Hangul composition constants and function
    lines.append("/// Hangul syllable composition constants")
    lines.append("const HANGUL = struct {")
    lines.append("    const S_BASE: u21 = 0xAC00;")
    lines.append("    const L_BASE: u21 = 0x1100;")
    lines.append("    const V_BASE: u21 = 0x1161;")
    lines.append("    const T_BASE: u21 = 0x11A7;")
    lines.append("    const L_COUNT: u21 = 19;")
    lines.append("    const V_COUNT: u21 = 21;")
    lines.append("    const T_COUNT: u21 = 28;")
    lines.append("    const N_COUNT: u21 = V_COUNT * T_COUNT;")
    lines.append("    const S_COUNT: u21 = L_COUNT * N_COUNT;")
    lines.append("};")
    lines.append("")
    lines.append("/// Composes Hangul jamo algorithmically")
    lines.append("fn composeHangul(first: Codepoint, second: Codepoint) ?Codepoint {")
    lines.append("    // Check for L + V -> LV")
    lines.append("    if (first >= HANGUL.L_BASE and first < HANGUL.L_BASE + HANGUL.L_COUNT) {")
    lines.append("        if (second >= HANGUL.V_BASE and second < HANGUL.V_BASE + HANGUL.V_COUNT) {")
    lines.append("            const l_index = first - HANGUL.L_BASE;")
    lines.append("            const v_index = second - HANGUL.V_BASE;")
    lines.append("            return HANGUL.S_BASE + (l_index * HANGUL.N_COUNT) + (v_index * HANGUL.T_COUNT);")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    // Check for LV + T -> LVT")
    lines.append("    if (first >= HANGUL.S_BASE and first < HANGUL.S_BASE + HANGUL.S_COUNT) {")
    lines.append("        const s_index = first - HANGUL.S_BASE;")
    lines.append("        if (s_index % HANGUL.T_COUNT == 0) {")
    lines.append("            if (second > HANGUL.T_BASE and second < HANGUL.T_BASE + HANGUL.T_COUNT) {")
    lines.append("                return first + (second - HANGUL.T_BASE);")
    lines.append("            }")
    lines.append("        }")
    lines.append("    }")
    lines.append("")
    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ============================================================================
# Script Detection (UAX #24)
# ============================================================================

def parse_scripts(data: str) -> Dict[int, str]:
    """Parse Scripts.txt into a dictionary of code point -> script name."""
    scripts = {}
    for line in data.split('\n'):
        line = line.split('#')[0].strip()
        if not line:
            continue

        parts = line.split(';')
        if len(parts) < 2:
            continue

        range_part = parts[0].strip()
        script = parts[1].strip()

        if '..' in range_part:
            start, end = range_part.split('..')
            for cp in range(int(start, 16), int(end, 16) + 1):
                scripts[cp] = script
        else:
            scripts[int(range_part, 16)] = script

    return scripts


def generate_zig_scripts_table(scripts: Dict[int, str]) -> str:
    """Generate Zig source for script detection."""
    lines = []
    lines.append("//! Generated Unicode Script Properties (UAX #24)")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    # Get unique scripts
    unique_scripts = sorted(set(scripts.values()))

    # Generate Script enum
    lines.append("/// Unicode Script values")
    lines.append("pub const Script = enum(u8) {")
    for i, script in enumerate(unique_scripts):
        lines.append(f"    {script} = {i},")
    lines.append("    Unknown = 255,")
    lines.append("};")
    lines.append("")

    # Build two-stage table similar to CCC
    BLOCK_SIZE = 256
    MAX_CP = max(scripts.keys()) if scripts else 0
    num_blocks = (MAX_CP // BLOCK_SIZE) + 1

    # Create script ID mapping
    script_to_id = {s: i for i, s in enumerate(unique_scripts)}

    # Build stage2 blocks and deduplicate
    stage2_blocks = []
    stage1 = []
    block_to_idx = {}

    for block_num in range(num_blocks):
        block_start = block_num * BLOCK_SIZE
        block = []
        for offset in range(BLOCK_SIZE):
            cp = block_start + offset
            if cp in scripts:
                block.append(script_to_id[scripts[cp]])
            else:
                block.append(255)  # Unknown

        block_tuple = tuple(block)
        if block_tuple in block_to_idx:
            stage1.append(block_to_idx[block_tuple])
        else:
            idx = len(stage2_blocks) * BLOCK_SIZE
            block_to_idx[block_tuple] = idx
            stage2_blocks.append(block)
            stage1.append(idx)

    stage2 = []
    for block in stage2_blocks:
        stage2.extend(block)

    # Generate stage1 table
    lines.append(f"/// Stage 1 block index ({len(stage1)} entries)")
    lines.append("const script_stage1 = [_]u16{")
    for i in range(0, len(stage1), 16):
        chunk = stage1[i:i+16]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Generate stage2 table
    lines.append(f"/// Stage 2 script values ({len(stage2)} entries)")
    lines.append("const script_stage2 = [_]u8{")
    for i in range(0, len(stage2), 32):
        chunk = stage2[i:i+32]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Lookup function
    lines.append("/// Gets the Script for a code point")
    lines.append("pub fn getScript(cp: Codepoint) Script {")
    lines.append("    if (cp > 0x10FFFF) return .Unknown;")
    lines.append("    const block = @as(usize, cp >> 8);")
    lines.append("    if (block >= script_stage1.len) return .Unknown;")
    lines.append("    const offset = @as(usize, cp & 0xFF);")
    lines.append("    const stage2_idx = script_stage1[block] + offset;")
    lines.append("    if (stage2_idx >= script_stage2.len) return .Unknown;")
    lines.append("    return @enumFromInt(script_stage2[stage2_idx]);")
    lines.append("}")
    lines.append("")

    # Convenience functions
    lines.append("/// Checks if a code point belongs to a specific script")
    lines.append("pub fn isScript(cp: Codepoint, script: Script) bool {")
    lines.append("    return getScript(cp) == script;")
    lines.append("}")
    lines.append("")

    lines.append("/// Checks if a string contains only characters from the given script (plus Common/Inherited)")
    lines.append("pub fn isScriptHomogeneous(text: []const u8, script: Script) bool {")
    lines.append("    const std = @import(\"std\");")
    lines.append("    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };")
    lines.append("    while (iter.nextCodepoint()) |cp| {")
    lines.append("        const s = getScript(cp);")
    lines.append("        if (s != script and s != .Common and s != .Inherited) {")
    lines.append("            return false;")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return true;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ============================================================================
# Line Breaking (UAX #14)
# ============================================================================

def parse_line_break(data: str) -> Dict[int, str]:
    """Parse LineBreak.txt into a dictionary of code point -> line break class."""
    lb_classes = {}
    for line in data.split('\n'):
        line = line.split('#')[0].strip()
        if not line:
            continue

        parts = line.split(';')
        if len(parts) < 2:
            continue

        range_part = parts[0].strip()
        lb_class = parts[1].strip()

        if '..' in range_part:
            start, end = range_part.split('..')
            for cp in range(int(start, 16), int(end, 16) + 1):
                lb_classes[cp] = lb_class
        else:
            lb_classes[int(range_part, 16)] = lb_class

    return lb_classes


def generate_zig_line_break_table(lb_classes: Dict[int, str]) -> str:
    """Generate Zig source for line breaking properties."""
    lines = []
    lines.append("//! Generated Unicode Line Break Properties (UAX #14)")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const std = @import(\"std\");")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    # Get unique line break classes
    unique_classes = sorted(set(lb_classes.values()))

    # Generate LineBreakClass enum
    lines.append("/// Unicode Line Break Classes (UAX #14)")
    lines.append("pub const LineBreakClass = enum(u8) {")
    for i, cls in enumerate(unique_classes):
        lines.append(f"    {cls} = {i},")
    # Only add XX if not already present in the data
    if "XX" not in unique_classes:
        lines.append("    XX = 255, // Unknown")
    lines.append("};")
    lines.append("")

    # Build two-stage table
    BLOCK_SIZE = 256
    MAX_CP = max(lb_classes.keys()) if lb_classes else 0
    num_blocks = (MAX_CP // BLOCK_SIZE) + 1

    class_to_id = {c: i for i, c in enumerate(unique_classes)}

    stage2_blocks = []
    stage1 = []
    block_to_idx = {}

    for block_num in range(num_blocks):
        block_start = block_num * BLOCK_SIZE
        block = []
        for offset in range(BLOCK_SIZE):
            cp = block_start + offset
            if cp in lb_classes:
                block.append(class_to_id[lb_classes[cp]])
            else:
                block.append(255)  # XX (unknown)

        block_tuple = tuple(block)
        if block_tuple in block_to_idx:
            stage1.append(block_to_idx[block_tuple])
        else:
            idx = len(stage2_blocks) * BLOCK_SIZE
            block_to_idx[block_tuple] = idx
            stage2_blocks.append(block)
            stage1.append(idx)

    stage2 = []
    for block in stage2_blocks:
        stage2.extend(block)

    # Generate tables
    lines.append(f"/// Stage 1 block index ({len(stage1)} entries)")
    lines.append("const lb_stage1 = [_]u16{")
    for i in range(0, len(stage1), 16):
        chunk = stage1[i:i+16]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    lines.append(f"/// Stage 2 line break class values ({len(stage2)} entries)")
    lines.append("const lb_stage2 = [_]u8{")
    for i in range(0, len(stage2), 32):
        chunk = stage2[i:i+32]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Lookup function
    lines.append("/// Gets the Line Break Class for a code point")
    lines.append("pub fn getLineBreakClass(cp: Codepoint) LineBreakClass {")
    lines.append("    if (cp > 0x10FFFF) return .XX;")
    lines.append("    const block = @as(usize, cp >> 8);")
    lines.append("    if (block >= lb_stage1.len) return .XX;")
    lines.append("    const offset = @as(usize, cp & 0xFF);")
    lines.append("    const stage2_idx = lb_stage1[block] + offset;")
    lines.append("    if (stage2_idx >= lb_stage2.len) return .XX;")
    lines.append("    return @enumFromInt(lb_stage2[stage2_idx]);")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ============================================================================
# Bidirectional Algorithm (UAX #9)
# ============================================================================

def parse_bidi_class(data: str) -> Dict[int, str]:
    """Parse DerivedBidiClass.txt or extract from UnicodeData.txt."""
    bidi_classes = {}
    for line in data.split('\n'):
        line = line.split('#')[0].strip()
        if not line:
            continue

        parts = line.split(';')
        if len(parts) < 2:
            continue

        range_part = parts[0].strip()
        bidi = parts[1].strip()

        if '..' in range_part:
            start, end = range_part.split('..')
            for cp in range(int(start, 16), int(end, 16) + 1):
                bidi_classes[cp] = bidi
        else:
            bidi_classes[int(range_part, 16)] = bidi

    return bidi_classes


def generate_zig_bidi_table(bidi_classes: Dict[int, str]) -> str:
    """Generate Zig source for bidirectional properties."""
    lines = []
    lines.append("//! Generated Unicode Bidirectional Properties (UAX #9)")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const std = @import(\"std\");")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    # Get unique bidi classes
    unique_classes = sorted(set(bidi_classes.values()))

    # Generate BidiClass enum
    lines.append("/// Unicode Bidirectional Character Types (UAX #9)")
    lines.append("pub const BidiClass = enum(u8) {")
    for i, cls in enumerate(unique_classes):
        lines.append(f"    {cls} = {i},")
    lines.append("};")
    lines.append("")

    # Build two-stage table
    BLOCK_SIZE = 256
    MAX_CP = max(bidi_classes.keys()) if bidi_classes else 0
    num_blocks = (MAX_CP // BLOCK_SIZE) + 1

    class_to_id = {c: i for i, c in enumerate(unique_classes)}
    default_id = class_to_id.get('L', 0)  # Default to Left-to-Right

    stage2_blocks = []
    stage1 = []
    block_to_idx = {}

    for block_num in range(num_blocks):
        block_start = block_num * BLOCK_SIZE
        block = []
        for offset in range(BLOCK_SIZE):
            cp = block_start + offset
            if cp in bidi_classes:
                block.append(class_to_id[bidi_classes[cp]])
            else:
                block.append(default_id)

        block_tuple = tuple(block)
        if block_tuple in block_to_idx:
            stage1.append(block_to_idx[block_tuple])
        else:
            idx = len(stage2_blocks) * BLOCK_SIZE
            block_to_idx[block_tuple] = idx
            stage2_blocks.append(block)
            stage1.append(idx)

    stage2 = []
    for block in stage2_blocks:
        stage2.extend(block)

    # Generate tables
    lines.append(f"/// Stage 1 block index ({len(stage1)} entries)")
    lines.append("const bidi_stage1 = [_]u16{")
    for i in range(0, len(stage1), 16):
        chunk = stage1[i:i+16]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    lines.append(f"/// Stage 2 bidi class values ({len(stage2)} entries)")
    lines.append("const bidi_stage2 = [_]u8{")
    for i in range(0, len(stage2), 32):
        chunk = stage2[i:i+32]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Lookup function
    lines.append("/// Gets the Bidi Class for a code point")
    lines.append("pub fn getBidiClass(cp: Codepoint) BidiClass {")
    lines.append("    if (cp > 0x10FFFF) return .L;")
    lines.append("    const block = @as(usize, cp >> 8);")
    lines.append("    if (block >= bidi_stage1.len) return .L;")
    lines.append("    const offset = @as(usize, cp & 0xFF);")
    lines.append("    const stage2_idx = bidi_stage1[block] + offset;")
    lines.append("    if (stage2_idx >= bidi_stage2.len) return .L;")
    lines.append("    return @enumFromInt(bidi_stage2[stage2_idx]);")
    lines.append("}")
    lines.append("")

    # Add helper functions for common checks
    lines.append("/// Checks if a bidi class is a strong type (L, R, AL)")
    lines.append("pub fn isStrong(class: BidiClass) bool {")
    lines.append("    return class == .L or class == .R or class == .AL;")
    lines.append("}")
    lines.append("")

    lines.append("/// Checks if a bidi class is right-to-left (R, AL)")
    lines.append("pub fn isRightToLeft(class: BidiClass) bool {")
    lines.append("    return class == .R or class == .AL;")
    lines.append("}")
    lines.append("")

    lines.append("/// Gets the base direction for a string (first strong character)")
    lines.append("pub fn getBaseDirection(text: []const u8) ?BidiClass {")
    lines.append("    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };")
    lines.append("    while (iter.nextCodepoint()) |cp| {")
    lines.append("        const class = getBidiClass(cp);")
    lines.append("        if (isStrong(class)) {")
    lines.append("            return class;")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


# ============================================================================
# Identifier Syntax (UAX #31)
# ============================================================================

def parse_derived_core_properties(data: str) -> Tuple[Set[int], Set[int]]:
    """Parse DerivedCoreProperties.txt for XID_Start and XID_Continue."""
    xid_start = set()
    xid_continue = set()

    for line in data.split('\n'):
        line = line.split('#')[0].strip()
        if not line:
            continue

        parts = line.split(';')
        if len(parts) < 2:
            continue

        range_part = parts[0].strip()
        prop = parts[1].strip()

        if prop not in ('XID_Start', 'XID_Continue'):
            continue

        if '..' in range_part:
            start, end = range_part.split('..')
            cps = range(int(start, 16), int(end, 16) + 1)
        else:
            cps = [int(range_part, 16)]

        if prop == 'XID_Start':
            xid_start.update(cps)
        else:
            xid_continue.update(cps)

    return xid_start, xid_continue


def generate_zig_identifier_table(xid_start: Set[int], xid_continue: Set[int]) -> str:
    """Generate Zig source for identifier syntax properties."""
    lines = []
    lines.append("//! Generated Unicode Identifier Properties (UAX #31)")
    lines.append("//! Unicode version: " + UNICODE_VERSION)
    lines.append("//! DO NOT EDIT - generated by tools/generate_ucd.py")
    lines.append("")
    lines.append("const std = @import(\"std\");")
    lines.append("const types = @import(\"types\");")
    lines.append("const Codepoint = types.Codepoint;")
    lines.append("")

    # Build two-stage table with bit flags
    # Bit 0: XID_Start, Bit 1: XID_Continue
    BLOCK_SIZE = 256
    all_cps = xid_start | xid_continue
    MAX_CP = max(all_cps) if all_cps else 0
    num_blocks = (MAX_CP // BLOCK_SIZE) + 1

    stage2_blocks = []
    stage1 = []
    block_to_idx = {}

    for block_num in range(num_blocks):
        block_start = block_num * BLOCK_SIZE
        block = []
        for offset in range(BLOCK_SIZE):
            cp = block_start + offset
            flags = 0
            if cp in xid_start:
                flags |= 1
            if cp in xid_continue:
                flags |= 2
            block.append(flags)

        block_tuple = tuple(block)
        if block_tuple in block_to_idx:
            stage1.append(block_to_idx[block_tuple])
        else:
            idx = len(stage2_blocks) * BLOCK_SIZE
            block_to_idx[block_tuple] = idx
            stage2_blocks.append(block)
            stage1.append(idx)

    stage2 = []
    for block in stage2_blocks:
        stage2.extend(block)

    # Generate tables
    lines.append(f"/// Stage 1 block index ({len(stage1)} entries)")
    lines.append("const id_stage1 = [_]u16{")
    for i in range(0, len(stage1), 16):
        chunk = stage1[i:i+16]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    lines.append(f"/// Stage 2 identifier flags ({len(stage2)} entries)")
    lines.append("/// Bit 0: XID_Start, Bit 1: XID_Continue")
    lines.append("const id_stage2 = [_]u8{")
    for i in range(0, len(stage2), 32):
        chunk = stage2[i:i+32]
        lines.append("    " + ", ".join(f"{x}" for x in chunk) + ",")
    lines.append("};")
    lines.append("")

    # Helper function to get flags
    lines.append("fn getIdFlags(cp: Codepoint) u8 {")
    lines.append("    if (cp > 0x10FFFF) return 0;")
    lines.append("    const block = @as(usize, cp >> 8);")
    lines.append("    if (block >= id_stage1.len) return 0;")
    lines.append("    const offset = @as(usize, cp & 0xFF);")
    lines.append("    const stage2_idx = id_stage1[block] + offset;")
    lines.append("    if (stage2_idx >= id_stage2.len) return 0;")
    lines.append("    return id_stage2[stage2_idx];")
    lines.append("}")
    lines.append("")

    # Public functions
    lines.append("/// Checks if a code point has the XID_Start property")
    lines.append("/// XID_Start characters can begin an identifier")
    lines.append("pub fn isXidStart(cp: Codepoint) bool {")
    lines.append("    return (getIdFlags(cp) & 1) != 0;")
    lines.append("}")
    lines.append("")

    lines.append("/// Checks if a code point has the XID_Continue property")
    lines.append("/// XID_Continue characters can continue an identifier")
    lines.append("pub fn isXidContinue(cp: Codepoint) bool {")
    lines.append("    return (getIdFlags(cp) & 2) != 0;")
    lines.append("}")
    lines.append("")

    lines.append("/// Checks if a string is a valid Unicode identifier (UAX #31)")
    lines.append("pub fn isValidIdentifier(text: []const u8) bool {")
    lines.append("    if (text.len == 0) return false;")
    lines.append("")
    lines.append("    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };")
    lines.append("")
    lines.append("    // First character must be XID_Start")
    lines.append("    const first = iter.nextCodepoint() orelse return false;")
    lines.append("    if (!isXidStart(first)) return false;")
    lines.append("")
    lines.append("    // Remaining characters must be XID_Continue")
    lines.append("    while (iter.nextCodepoint()) |cp| {")
    lines.append("        if (!isXidContinue(cp)) return false;")
    lines.append("    }")
    lines.append("")
    lines.append("    return true;")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def main():
    print(f"Unicode Character Database Table Generator")
    print(f"Unicode version: {UNICODE_VERSION}")
    print()

    # Download required files
    unicode_data = download_file("UnicodeData.txt")
    comp_exclusions = download_file("CompositionExclusions.txt")
    scripts_data = download_file("Scripts.txt")
    line_break_data = download_file("LineBreak.txt")
    bidi_data = download_file("extracted/DerivedBidiClass.txt")
    derived_props = download_file("DerivedCoreProperties.txt")

    # Parse data
    print("Parsing UnicodeData.txt...")
    entries = parse_unicode_data(unicode_data)
    print(f"  Parsed {len(entries)} code point entries")

    print("Parsing CompositionExclusions.txt...")
    exclusions = parse_composition_exclusions(comp_exclusions)
    print(f"  Found {len(exclusions)} composition exclusions")

    print("Parsing Scripts.txt...")
    scripts = parse_scripts(scripts_data)
    print(f"  {len(scripts)} script mappings")

    print("Parsing LineBreak.txt...")
    lb_classes = parse_line_break(line_break_data)
    print(f"  {len(lb_classes)} line break mappings")

    print("Parsing DerivedBidiClass.txt...")
    bidi_classes = parse_bidi_class(bidi_data)
    print(f"  {len(bidi_classes)} bidi class mappings")

    print("Parsing DerivedCoreProperties.txt...")
    xid_start, xid_continue = parse_derived_core_properties(derived_props)
    print(f"  {len(xid_start)} XID_Start, {len(xid_continue)} XID_Continue")

    # Build tables
    print("Building CCC table...")
    ccc_stage1, ccc_stage2 = build_ccc_table(entries)
    print(f"  Stage 1: {len(ccc_stage1)} blocks")
    print(f"  Stage 2: {len(ccc_stage2)} entries")

    print("Building decomposition table...")
    decompositions = build_decomposition_table(entries)
    print(f"  {len(decompositions)} decomposition mappings")

    print("Building composition table...")
    compositions = build_composition_table(entries, exclusions)
    print(f"  {len(compositions)} composition pairs")

    # Generate Zig source files
    output_dir = os.path.join(os.path.dirname(__file__), "..", "src", "unicode", "data")
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating Zig source files in {output_dir}...")

    ccc_zig = generate_zig_ccc_table(ccc_stage1, ccc_stage2)
    with open(os.path.join(output_dir, "ccc.zig"), 'w') as f:
        f.write(ccc_zig)
    print(f"  Generated ccc.zig ({len(ccc_zig)} bytes)")

    decomp_zig = generate_zig_decomposition_table(decompositions)
    with open(os.path.join(output_dir, "decomposition.zig"), 'w') as f:
        f.write(decomp_zig)
    print(f"  Generated decomposition.zig ({len(decomp_zig)} bytes)")

    comp_zig = generate_zig_composition_table(compositions)
    with open(os.path.join(output_dir, "composition.zig"), 'w') as f:
        f.write(comp_zig)
    print(f"  Generated composition.zig ({len(comp_zig)} bytes)")

    scripts_zig = generate_zig_scripts_table(scripts)
    with open(os.path.join(output_dir, "scripts.zig"), 'w') as f:
        f.write(scripts_zig)
    print(f"  Generated scripts.zig ({len(scripts_zig)} bytes)")

    lb_zig = generate_zig_line_break_table(lb_classes)
    with open(os.path.join(output_dir, "line_break.zig"), 'w') as f:
        f.write(lb_zig)
    print(f"  Generated line_break.zig ({len(lb_zig)} bytes)")

    bidi_zig = generate_zig_bidi_table(bidi_classes)
    with open(os.path.join(output_dir, "bidi.zig"), 'w') as f:
        f.write(bidi_zig)
    print(f"  Generated bidi.zig ({len(bidi_zig)} bytes)")

    id_zig = generate_zig_identifier_table(xid_start, xid_continue)
    with open(os.path.join(output_dir, "identifier.zig"), 'w') as f:
        f.write(id_zig)
    print(f"  Generated identifier.zig ({len(id_zig)} bytes)")

    print()
    print("Done! Generated tables for Unicode", UNICODE_VERSION)


if __name__ == "__main__":
    main()
