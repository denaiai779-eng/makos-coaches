# Builds index.html from src.html: injects the public Supabase anon key (same one the Makos app ships)
# and the Rochester/Southfield hitting groups from the 11U groups workbook.
import json, os, re, openpyxl
HERE = os.path.dirname(os.path.abspath(__file__))
makos = open(os.path.join(HERE, '../return-to-quality/index.html')).read()
key = re.search(r"const SUPABASE_KEY = '([^']+)'", makos).group(1)
ids = {m.group(2): m.group(1) for m in re.finditer(r"\{ id: '([a-z0-9-]+)', name: \"([^\"]+)\"", makos)}
wb = openpyxl.load_workbook(os.path.expanduser('~/Desktop/Makos/11U Practice Plans/Makos_11U_Groups_and_Practice_Plan.xlsx'), data_only=True)
groups = {}
for r in wb['Groups'].iter_rows(min_row=4, values_only=True):
    if r[1] in ids and r[3] in ('Rochester', 'Southfield'):
        groups[ids[r[1]]] = r[3]
src = open(os.path.join(HERE, 'src.html')).read()
out = src.replace('__KEY__', key).replace('__GROUPS__', json.dumps(groups, sort_keys=True))
open(os.path.join(HERE, 'index.html'), 'w').write(out)
print(f'{len(groups)} players grouped')
