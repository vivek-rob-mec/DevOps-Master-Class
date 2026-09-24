import pathlib,re,sys
SHA=re.compile(r"^[0-9a-f]{40}$")
def invalid_references(text):
 findings=[]
 for number,line in enumerate(text.splitlines(),1):
  match=re.search(r"\buses:\s*([^\s#]+)",line)
  if not match:continue
  ref=match.group(1)
  if ref.startswith("./") or ref.startswith("docker://"):continue
  if "@" not in ref or not SHA.fullmatch(ref.rsplit("@",1)[1]):findings.append((number,ref))
 return findings
def main(root):
 failures=[]
 for path in pathlib.Path(root).rglob("*.y*ml"):
  for line,ref in invalid_references(path.read_text(encoding="utf-8")):failures.append(f"{path}:{line}: mutable action {ref}")
 if failures:print("\n".join(failures));return 1
 print("All third-party actions use immutable commit SHAs.");return 0
if __name__=="__main__":raise SystemExit(main(sys.argv[1] if len(sys.argv)>1 else ".github/workflows"))
