# Chinese pronunciation dictionary

`zh-pronunciation.json` is a derived dictionary for the Chinese similar-sound
activity. It contains 14,876 entries with a word (`term`), subtitle occurrence
count (`count`), and numbered-pinyin `readings`. Syllables are separated by spaces,
`v` represents ü, and tone 5 is neutral. Runtime lookup needs no network or Python.

## Sources and licensing

The combined dictionary is distributed under **Creative Commons
Attribution-ShareAlike 4.0 International**:
[license and full terms](https://creativecommons.org/licenses/by-sa/4.0/).
Retain this attribution and the MIT notices below when redistributing it.

- **Hermit Dave, FrequencyWords**, derived from **OpenSubtitles 2018**:
  [source repository and attribution](https://github.com/hermitdave/FrequencyWords),
  [pinned Chinese frequency list](https://github.com/hermitdave/FrequencyWords/blob/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/zh_cn/zh_cn_50k.txt).
  Frequency data is CC BY-SA 4.0 (the generator's MIT license does not apply
  to the frequency data).
- **mozillazg and contributors, phrase-pinyin-data**, version 0.19.0:
  [pinned word readings](https://github.com/mozillazg/phrase-pinyin-data/blob/cee0ed6e6e4898580cafd2bd5e3723e20b214aa0/pinyin.txt),
  [MIT notice](licenses/phrase-pinyin-data-MIT.txt).
  We use `pinyin.txt`, not the separate merged `large_pinyin.txt` dataset.
- **mozillazg and contributors, pinyin-data**, version 0.15.0:
  [pinned character readings](https://github.com/mozillazg/pinyin-data/blob/923b108dc5d45dee061324c011b478fb649f8b73/pinyin.txt),
  [MIT notice](licenses/pinyin-data-MIT.txt).

## Reproduction and modifications

From the repository root:

```sh
python3 pipeline/scripts/build_chinese_dictionary.py
```

The build fetches three immutable source revisions. SHA-256 hashes of their raw
contents are stored in the output. For an offline build, pass `--source-dir DIR`
containing `frequency-zh_cn_50k.txt`, `pinyin-pinyin.txt`, and
`character-pinyin.txt` from those revisions.

The build removes non-Han entries, words longer than four characters, and entries
with fewer than 100 subtitle occurrences. It attaches complete word readings
first. If a word has no phrase reading, it combines character readings only when
every character has exactly one listed pronunciation. Entries without usable
readings are removed. Accented pinyin becomes numbered pinyin, and output is
sorted by descending frequency then term. Both Simplified and Traditional
spellings can remain; this is not a script-conversion dictionary.

## Matching and limits

`ChineseSounds` skips words with multiple listed readings because the lookup
has no sentence-level pronunciation disambiguation. It requires equal syllable
counts and allows only one syllable to change: one pinyin spelling edit costs 1,
a tone change costs 0.25, and the maximum score is 1.25. Candidates are ranked
by that score then frequency. Exact homophones (including script variants with
the same reading) are excluded, and only one candidate per pronunciation is
returned, up to three. This is a conservative pinyin approximation, not an
acoustic model; tone sandhi and contextual readings are not modeled.

The activity supports one- and two-character words. It preserves the pipeline's
existing word boundaries, punctuation, spacing, and one output line per phrase.
A Chinese run without a dictionary reading is left intact, including unsegmented
sentences; the step does not re-segment text and invalidate Rails word indexes.
Words or phrases without an audible alternative are left unchanged. Cached
completed imports are not automatically regenerated.
