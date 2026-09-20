import json

p = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs\compare_hes_paper_M20.json"
d = json.load(open(p, encoding="utf-8"))
t = d["tables"]
labels = t["labels"]
problems = d["problems"]
cells = [row.split("|") for row in t["cells"]]
counts = t["counts"]

print("anchor = %s" % t["anchor"])
print("labels = %s" % " | ".join(labels))
hdr = "%-6s" % "Problem" + "".join("  %-26s" % l for l in labels)
print(hdr)
for i, prob in enumerate(problems):
    print("%-6s" % prob + "".join("  %-26s" % cells[i][j] for j in range(len(labels))))
print("%-6s" % "+/-/=" + "".join("  %-26s" % c for c in counts) + "  <anchor no sign>")

# which problems does HES win/lose vs PACDIS
hi = labels.index("HES_EA_N100")
ai = labels.index("PACDIS")
wins, losses, ties = [], [], []
for i, prob in enumerate(problems):
    s = cells[i][hi].strip()[-1]   # the sign is the last character of the cell
    if s == "+":
        wins.append(prob)
    elif s == "-":
        losses.append(prob)
    else:
        ties.append(prob)
print("\nHES_EA_N100 vs PACDIS:")
print("  wins(+)  :", ", ".join(wins))
print("  losses(-):", ", ".join(losses))
print("  ties(=)  :", ", ".join(ties))
