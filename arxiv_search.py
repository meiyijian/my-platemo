import urllib.request, urllib.parse, xml.etree.ElementTree as ET, time, sys, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

def search(query, max_results=25, sort="relevance"):
    base = "http://export.arxiv.org/api/query?"
    params = {
        "search_query": query,
        "start": 0,
        "max_results": max_results,
        "sortBy": sort,          # relevance | submittedDate | lastUpdatedDate
        "sortOrder": "descending",
    }
    url = base + urllib.parse.urlencode(params)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                return r.read()
        except Exception as e:
            time.sleep(3)
    return None

ns = {"a": "http://www.w3.org/2005/Atom"}

def parse(data):
    out = []
    if not data:
        return out
    root = ET.fromstring(data)
    for e in root.findall("a:entry", ns):
        title = " ".join(e.find("a:title", ns).text.split())
        pub = e.find("a:published", ns).text[:10]
        idurl = e.find("a:id", ns).text
        authors = [a.find("a:name", ns).text for a in e.findall("a:author", ns)]
        summ = " ".join(e.find("a:summary", ns).text.split())
        cats = [c.attrib.get("term") for c in e.findall("a:category", ns)]
        out.append({
            "title": title, "pub": pub, "id": idurl,
            "authors": authors, "summary": summ, "cats": cats,
        })
    return out

# queries passed as: python arxiv_search.py "relevance|MAX|the query" ...
for spec in sys.argv[1:]:
    sort, mx, q = spec.split("|", 2)
    print("\n" + "="*90)
    print("QUERY:", q, " [sort=%s]" % sort)
    print("="*90)
    data = search(q, max_results=int(mx), sort=sort)
    items = parse(data)
    if not items:
        print("  (no results / error)")
    for it in items:
        print(f"\n[{it['pub']}] {it['title']}")
        print("  ", it["id"])
        print("   authors:", ", ".join(it["authors"][:4]), ("et al." if len(it["authors"])>4 else ""))
        print("   cats:", ",".join(c for c in it["cats"] if c))
        print("   abs:", it["summary"][:300])
    time.sleep(2)
