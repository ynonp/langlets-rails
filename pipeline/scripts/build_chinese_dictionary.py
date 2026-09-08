"""Build the bundled Chinese pronunciation dictionary from pinned public sources.

Run from any directory: python3 pipeline/scripts/build_chinese_dictionary.py
Use --source-dir /path/to/downloads to rebuild offline from the named source files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import unicodedata
import urllib.request

SOURCES = {
    "frequency-zh_cn_50k.txt": ("hermitdave/FrequencyWords", "525f9b560de45753a5ea01069454e72e9aa541c6", "content/2018/zh_cn/zh_cn_50k.txt"),
    "pinyin-pinyin.txt": ("mozillazg/phrase-pinyin-data", "cee0ed6e6e4898580cafd2bd5e3723e20b214aa0", "pinyin.txt"),
    "character-pinyin.txt": ("mozillazg/pinyin-data", "923b108dc5d45dee061324c011b478fb649f8b73", "pinyin.txt"),
}


def numbered(syllable):
    tone = 5
    letters = ""
    for char in unicodedata.normalize("NFD", syllable):
        if char in "\u0304\u0301\u030c\u0300":
            tone = "\u0304\u0301\u030c\u0300".index(char) + 1
        elif char == "\u0308" and letters.endswith("u"):
            letters = letters[:-1] + "v"
        elif "a" <= char <= "z":
            letters += char
        else:
            return None
    return letters + str(tone) if letters else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path)
    args = parser.parse_args()
    sources = {}
    checksums = {}
    for name, (repo, revision, file) in SOURCES.items():
        raw = (args.source_dir / name).read_bytes() if args.source_dir else urllib.request.urlopen(
            f"https://raw.githubusercontent.com/{repo}/{revision}/{file}", timeout=30
        ).read()
        sources[name] = raw.decode("utf-8")
        checksums[name] = hashlib.sha256(raw).hexdigest()

    readings = {}
    for line in sources["pinyin-pinyin.txt"].splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        word, pronunciation = line.split(":", 1)
        syllables = [numbered(s) for s in pronunciation.split()]
        if len(syllables) == len(word) and all(syllables):
            readings.setdefault(word, set()).add(" ".join(syllables))

    characters = {}
    for line in sources["character-pinyin.txt"].splitlines():
        if not line.startswith("U+"):
            continue
        code, pronunciations = line.split("#", 1)[0].strip().split(":", 1)
        values = {numbered(s.strip()) for s in pronunciations.split(",")}
        # Do not guess a polyphonic character's reading inside an unknown word.
        if len(values) == 1 and None not in values:
            characters[chr(int(code[2:], 16))] = next(iter(values))

    entries = []
    for line in sources["frequency-zh_cn_50k.txt"].splitlines():
        word, count = line.rsplit(" ", 1)
        count = int(count)
        if count < 100 or not re.fullmatch(r"[\u3400-\u4dbf\u4e00-\u9fff]{1,4}", word):
            continue
        variants = readings.get(word)
        if not variants and all(c in characters for c in word):
            variants = {" ".join(characters[c] for c in word)}
        if variants:
            entries.append({"term": word, "count": count, "readings": sorted(variants)})
    entries.sort(key=lambda entry: (-entry["count"], entry["term"]))
    output = Path(__file__).resolve().parents[1] / "data" / "zh-pronunciation.json"
    output.write_text(json.dumps({"sources_sha256": checksums, "entries": entries}, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} entries ({output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
