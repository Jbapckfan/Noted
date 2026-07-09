#!/usr/bin/env python3
"""
Build the LoRA training corpus for NotedCore from the datasets already in the repo.

Outputs mlx_lm chat-format JSONL (one {"messages":[user, assistant]} per line), task-tagged:
  - note:       MTS-Dialog dialogue -> clinical note section (bulk supervised summarization)
  - extraction: gold ED transcript -> ClinicalFacts JSON (the fact backbone, from our 5 gold cases)

The `note` task teaches summarization; the `extraction` task teaches the grounded fact JSON the
deterministic template + verifier consume. James's real de-identified pairs get appended later
(same schema) — this is the seed corpus.

Run:  python3 training/convert.py
Out:  training/data/{train,valid}.jsonl  + a per-task breakdown printed to stdout
"""
import csv, json, random, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(__file__).resolve().parent / "data"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(7)  # deterministic split

EXTRACTION_INSTRUCTION = (
    "You are an emergency medicine scribe. Extract the clinical facts from this ED transcript as a "
    "single JSON object with keys chief_complaint, hpi, review_of_systems, past_medical_history, "
    "allergies, medications[{drug,dose,route,frequency}], vitals[{name,value}], physical_exam, "
    "labs[{test,value,unit}], mdm, diagnosis, differential, disposition, return_precautions. "
    "Quote every number, dose, and result VERBATIM; never invent a value. Omit anything not stated."
)

def chat(user: str, assistant: str, task: str) -> dict:
    return {"task": task, "messages": [
        {"role": "user", "content": user},
        {"role": "assistant", "content": assistant},
    ]}

# ---- 1. MTS-Dialog: dialogue -> note section (the bulk "note" task) -------------------------
def mts_dialog_examples() -> list[dict]:
    csv.field_size_limit(10_000_000)
    path = ROOT / "MedicalDatasets/MTS-Dialog/Main-Dataset/MTS-Dialog-TrainingSet.csv"
    out = []
    if not path.exists():
        print(f"! MTS-Dialog not found at {path}", file=sys.stderr)
        return out
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            dialogue = (row.get("dialogue") or "").strip()
            note = (row.get("section_text") or "").strip()
            header = (row.get("section_header") or "NOTE").strip()
            if not dialogue or not note:
                continue
            user = f"Summarize this clinical encounter into the {header} section of the note:\n\n{dialogue}"
            out.append(chat(user, note, task="note"))
    return out

# ---- 2. Gold ED cases -> ClinicalFacts extraction JSON (the "extraction" task) --------------
def ed_extraction_examples() -> list[dict]:
    path = ROOT / "NotedCoreKit/Tests/NotedCoreKitTests/Fixtures/verifier-test-matrix.json"
    out = []
    if not path.exists():
        print(f"! verifier matrix not found at {path}", file=sys.stderr)
        return out
    matrix = json.loads(path.read_text())
    for case in matrix.get("cases", []):
        transcript = case.get("transcriptExcerpt", "").strip()
        g = case.get("goldFacts", {})
        if not transcript:
            continue
        facts = {
            "chief_complaint": case.get("chiefComplaint", ""),
            "medications": [
                {"drug": m.get("drug", ""), "dose": m.get("dose", ""),
                 "route": m.get("route", ""), "frequency": m.get("frequency", "")}
                for m in g.get("medications", [])
            ],
            "vitals": [{"name": v.get("name", ""), "value": v.get("value", "")} for v in g.get("vitals", [])],
            "labs": [{"test": l.get("test", ""), "value": l.get("value", ""), "unit": l.get("unit", "")}
                     for l in g.get("labs", [])],
            "diagnosis": g.get("diagnosis", ""),
            "return_precautions": g.get("returnPrecautions", []),
        }
        assistant = json.dumps(facts, ensure_ascii=False)
        out.append(chat(f"{EXTRACTION_INSTRUCTION}\n\nTranscript:\n{transcript}", assistant, task="extraction"))
    return out

def main():
    examples = mts_dialog_examples() + ed_extraction_examples()
    random.shuffle(examples)
    if not examples:
        print("no examples produced — check dataset paths", file=sys.stderr)
        sys.exit(1)

    n_valid = max(1, int(len(examples) * 0.05))
    valid, train = examples[:n_valid], examples[n_valid:]

    for name, rows in (("train", train), ("valid", valid)):
        with open(OUT / f"{name}.jsonl", "w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps({"messages": r["messages"]}, ensure_ascii=False) + "\n")

    by_task = {}
    for e in examples:
        by_task[e["task"]] = by_task.get(e["task"], 0) + 1
    print(f"wrote {len(train)} train + {len(valid)} valid to {OUT}")
    print("by task:", by_task)

if __name__ == "__main__":
    main()
