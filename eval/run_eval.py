#!/usr/bin/env python3
"""Run the REAL on-device model (Llama-3.2-3B-Instruct-4bit via mlx_lm) on each transcript with the
EXACT extraction prompt + sampling params from MLXNoteEngine, and save the extraction JSON. The
grounding + template step is then run by `swift run nc-summarize`."""
import sys, os, json, glob
from mlx_lm import load, generate
try:
    from mlx_lm.sample_utils import make_sampler
except Exception:
    make_sampler = None

MODEL = "mlx-community/Llama-3.2-3B-Instruct-4bit"
EVAL_DIR = os.path.dirname(os.path.abspath(__file__))

PROMPT_TMPL = """You are an emergency medicine scribe. Extract the clinical facts from this ED transcript as a single JSON object with EXACTLY these keys:
{{"chief_complaint": string, "hpi": string, "review_of_systems": string,
 "past_medical_history": [string], "allergies": [string],
 "medications": [{{"drug","dose","route","frequency"}}],
 "vitals": [{{"name","value"}}], "physical_exam": string,
 "labs": [{{"test","value","unit"}}], "mdm": string, "diagnosis": string,
 "differential": [string], "disposition": string, "return_precautions": [string]}}

Rules: quote every number, dose, and result VERBATIM as spoken; never invent a value, a medication, a dose, or a result. Omit anything not stated. The HPI must be a fluent narrative in complete sentences; the MDM must state the reasoning and what was ruled out.

Transcript:
{transcript}"""

def extract_json(text):
    s, e = text.find("{"), text.rfind("}")
    return text[s:e+1] if (s != -1 and e != -1 and e > s) else None

print(f"loading {MODEL} ...", flush=True)
model, tokenizer = load(MODEL)
sampler = make_sampler(temp=0.3, top_p=0.9) if make_sampler else None

for tf in sorted(glob.glob(os.path.join(EVAL_DIR, "*.txt"))):
    name = os.path.splitext(os.path.basename(tf))[0]
    transcript = open(tf).read()
    prompt = PROMPT_TMPL.format(transcript=transcript)
    text = tokenizer.apply_chat_template(
        [{"role": "user", "content": prompt}], add_generation_prompt=True, tokenize=False
    )
    kwargs = {"max_tokens": 768, "verbose": False}
    if sampler is not None:
        kwargs["sampler"] = sampler
    try:
        out = generate(model, tokenizer, prompt=text, **kwargs)
    except TypeError:
        out = generate(model, tokenizer, prompt=text, max_tokens=768, verbose=False)

    js = extract_json(out)
    outpath = os.path.join(EVAL_DIR, name + ".json")
    saved = "{}"
    if js:
        try:
            saved = json.dumps(json.loads(js), indent=2)
        except Exception:
            saved = js  # save raw so we can see malformed output too
    open(outpath, "w").write(saved)
    print(f"\n===================== {name} =====================")
    print("RAW MODEL OUTPUT (truncated):")
    print(out[:1400])
    print(f"[saved extraction → {name}.json]")
