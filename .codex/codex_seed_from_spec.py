# .codex/codex_seed_from_spec.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, io, re, datetime

REPO   = os.path.abspath(os.environ.get("REPO", "."))
MIN_OPEN = int(os.environ.get("MIN_OPEN", "5"))
ADD_N    = int(os.environ.get("ADD_N", "10"))

TASKS = os.path.join(REPO, "docs", "CODEX_TASKS.md")
SPEC  = os.path.join(REPO, "docs", "TECH_SPEC.md")

def now(): return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

def read(path):
    if not os.path.exists(path): return ""
    with io.open(path,"r",encoding="utf-8",errors="replace") as f: return f.read()

def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path,"w",encoding="utf-8") as f: f.write(data)

def norm(s: str) -> str:
    s = re.sub(r'\s+', ' ', s).strip(' ;.·—–-')
    return s

def parse_open_tasks(md: str):
    return [m.group(2).strip() for m in re.finditer(r'^(\s*)-\s*\[\s\]\s*(.+)$', md, re.M)]

def parse_all_tasks_texts(md: str):
    return {norm(m.group(2)) for m in re.finditer(r'^(\s*)-\s*\[\s?[xX]?\s?\]\s*(.+)$', md, re.M)}

def extract_from_spec(spec: str):
    tasks = []
    if not spec: return tasks
    lines = spec.splitlines()

    for m in re.finditer(r'^\s*-\s*\[\s?\]\s*(.+)$', spec, re.M):
        tasks.append(norm(m.group(1)))

    sec3_idxs = [i for i,l in enumerate(lines) if re.match(r'^\s*3(\.\d+)?\s', l)]
    sec3_idxs.append(len(lines))
    for k in range(len(sec3_idxs)-1):
        block = lines[sec3_idxs[k]:sec3_idxs[k+1]]
        for ln in block:
            m = re.match(r'^\s*[-*+]\s+(.*)', ln)
            if m:
                t = norm(m.group(1))
                if t: tasks.append(t)

    for m in re.finditer(r'^\s*svc-[\w-]+\s*(\(.+?\))?:\s*(.+)$', spec, re.M):
        svc_line = norm(m.group(0))
        svc_name_m = re.search(r'(svc-[\w-]+)', svc_line)
        if svc_name_m:
            svc = svc_name_m.group(1)
            tasks.extend([
                f"Скелет {svc}: NestJS модуль/контроллер, Prisma модель, /health",
                f"{svc}: миграции Prisma (init) и базовые CRUD/контракты",
            ])

    for m in re.finditer(r'^\s*(GET|POST|PATCH|PUT|DELETE)\s+(/[^\s]+)\s*(.*)$', spec, re.M|re.I):
        method = m.group(1).upper(); path = m.group(2); desc = norm(m.group(3) or "")
        tail = f" ({desc})" if desc else ""
        tasks.append(f"API {method} {path}: реализовать по ТЗ{tail}")

    if re.search(r'^\s*5\.1\s', spec, re.M):
        tasks.append("Prisma схемы по разделу 5.1: ядро домена (User/Couple/Vendor/Venue/Enquiry/Review/Guest/Table/BudgetItem/AvailabilitySlot/Offer)")

    if re.search(r'^\s*11\.\s*CI/?CD', spec, re.M|re.I):
        tasks.extend([
            "GitHub Actions: auto-merge codex→main (squash), триггеры и required checks",
            "CI: линтер, юнит-тесты, миграции на тестовой БД, сборка",
        ])
    if re.search(r'^\s*15\.\s*DigitalOcean', spec, re.M|re.I):
        tasks.extend([
            "DigitalOcean App Platform: слушать $PORT/0.0.0.0, быстрый /health",
            "DO: prisma migrate deploy на старте; корректные scripts в package.json",
        ])

    out, seen = [], set()
    for t in tasks:
        t = norm(t)
        if not t: continue
        if len(t) > 200: t = t[:200] + '…'
        k = t.lower()
        if k in seen: continue
        seen.add(k); out.append(t)
    return out

def main():
    tasks_md = read(TASKS) or "# Tasks\n\n"
    spec_md  = read(SPEC)
    open_now = parse_open_tasks(tasks_md)
    all_seen = parse_all_tasks_texts(tasks_md)

    if len(open_now) >= MIN_OPEN:
        write(TASKS, tasks_md)
        return

    candidates = extract_from_spec(spec_md)
    new_items = []
    for t in candidates:
        if norm(t) not in all_seen:
            new_items.append(t)
        if len(new_items) >= ADD_N:
            break

    if not new_items:
        write(TASKS, tasks_md)
        return

    block = "\n".join(f"- [ ] {t}" for t in new_items)
    lines = tasks_md.splitlines()
    if not lines or not lines[0].lstrip().startswith("#"):
        lines.insert(0, "# Tasks"); lines.insert(1, "")

    insert_at = 2 if len(lines) >= 2 else len(lines)
    lines.insert(insert_at, block)
    out = ("\n".join(lines)).rstrip() + "\n"
    write(TASKS, out)

if __name__ == "__main__":
    main()

