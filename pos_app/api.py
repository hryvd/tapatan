"""
Sar-E Product Recognition API
==============================
FastAPI server that loads product_model.pth (MobileNetV3-Large)
and exposes a /predict endpoint for the Flutter app.

Usage:
  pip install fastapi uvicorn torch torchvision pillow
  python api.py
  # Runs on http://localhost:8000
"""

from __future__ import annotations

import os
import io
import json
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# ─── Config ───────────────────────────────────────────────────────────────────
MODEL_PATH = Path(__file__).parent / "product_model.pth"
CLASS_NAMES_PATH = Path(__file__).parent.parent.parent / \
    "cognate dataset" / "class_names.json"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
TOP_K = 3  # Return top-3 predictions

# ─── Philippine Grocery Mapping ───────────────────────────────────────────────
# Maps raw class indices / image-file class names to real product names.
# Extend this as your model is retrained with proper class labels.
PH_GROCERY_MAP: dict[str, str] = {
    "IMG_4042": "Lucky Me! Pancit Canton",
    "IMG_4043": "Lucky Me! Pancit Canton Chilimansi",
    "IMG_4044": "Nescafé 3-in-1 Original",
    "IMG_4045": "Bear Brand Powdered Milk",
    "IMG_4046": "Milo Chocolate Powder",
    "IMG_4047": "Safeguard Soap White",
    "IMG_4048": "Palmolive Shampoo (Sachet)",
    "IMG_4049": "Datu Puti Soy Sauce (Sachet)",
    "IMG_4050": "Datu Puti Vinegar (Sachet)",
    "IMG_4051": "UFC Banana Ketchup (Sachet)",
    "IMG_4052": "Maggi Magic Sarap",
    "IMG_4053": "Knorr Sinigang Mix",
    "IMG_4054": "Sky Flakes Crackers",
    "IMG_4055": "Rebisco Biscuits",
    "IMG_4056": "Piattos Cheese",
    "IMG_4057": "Nova Country Cheddar",
    "IMG_4058": "Regent Cheese Rings",
    "IMG_4059": "C2 Cool & Clean Green Tea",
    "IMG_4060": "Cobra Energy Drink",
    "IMG_4061": "Gatorade Blue Frost",
    "IMG_4062": "Red Horse Beer 500mL",
    "IMG_4063": "San Miguel Beer Pale Pilsen",
    "IMG_4064": "RC Cola 1.5L",
    "IMG_4065": "Sprite 1.5L",
    "IMG_4066": "Pepsi 1.5L",
    "IMG_4067": "Champion Detergent Bar",
    "IMG_4068": "Ariel Detergent (Sachet)",
    "IMG_4069": "Colgate Strong Teeth (Sachet)",
    "IMG_4070": "Hapee Toothpaste Bubble Mint",
    "IMG_4071": "Pantene Shampoo (Sachet)",
    "IMG_4072": "Head & Shoulders (Sachet)",
    "IMG_4073": "Alaska Evaporated Milk",
    "IMG_4074": "Anchor Cream (Sachet)",
    "IMG_4075": "Lady's Choice Mayonnaise (Sachet)",
    "IMG_4076": "Del Monte Tomato Sauce (Sachet)",
    "IMG_4077": "555 Sardines in Tomato Sauce",
    "IMG_4078": "Ligo Sardines in Chili",
    "IMG_4079": "Argentina Corned Beef",
    "IMG_4080": "Wow Sarap All-in-One Seasoning",
    "IMG_4081": "Eden Cheese 165g",
    "IMG_4082": "Marlboro Red Cigarette",
}


# ─── Load Model ───────────────────────────────────────────────────────────────

def load_model(num_classes: int) -> nn.Module:
    model = models.mobilenet_v3_large(weights=None)
    # Replace classifier head to match trained num_classes
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
    model.eval()
    return model.to(DEVICE)


# Load class names
idx_to_class: dict[str, str] = {}
num_classes = 41  # default from cognate dataset (0..40)

if CLASS_NAMES_PATH.exists():
    with open(CLASS_NAMES_PATH, "r") as f:
        cn = json.load(f)
        idx_to_class = cn.get("idx_to_class", {})
        num_classes = len(idx_to_class) if idx_to_class else num_classes
else:
    # Build from PH_GROCERY_MAP keys order
    idx_to_class = {str(i): k for i, k in enumerate(PH_GROCERY_MAP.keys())}

print(f"[Sar-E AI] Loading model: {MODEL_PATH} | Classes: {num_classes} | Device: {DEVICE}")

if not MODEL_PATH.exists():
    print("[Sar-E AI] WARNING: product_model.pth not found — running in MOCK mode")
    model = None
else:
    model = load_model(num_classes)
    print("[Sar-E AI] Model loaded successfully ✓")


# ─── Preprocessing ────────────────────────────────────────────────────────────

preprocess = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225],
    ),
])


# ─── FastAPI App ──────────────────────────────────────────────────────────────

app = FastAPI(
    title="Sar-E Product Recognition API",
    description="Runs product_model.pth to identify Filipino grocery products from images.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": model is not None,
        "num_classes": num_classes,
        "device": str(DEVICE),
    }


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    """
    Accept an image file and return top-K product predictions.
    Response:
    {
      "predictions": [
        {"rank": 1, "class_id": "IMG_4042", "product_name": "Lucky Me! Pancit Canton", "confidence": 0.92},
        ...
      ]
    }
    """
    # Validate image
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Upload must be an image file.")

    img_bytes = await file.read()
    try:
        image = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read image: {e}")

    # MOCK mode (model not found)
    if model is None:
        import random
        keys = list(PH_GROCERY_MAP.keys())
        mock_picks = random.sample(keys, min(TOP_K, len(keys)))
        return {
            "predictions": [
                {
                    "rank": i + 1,
                    "class_id": cls_key,
                    "product_name": PH_GROCERY_MAP.get(cls_key, cls_key),
                    "confidence": round(0.95 - i * 0.15, 4),
                    "mock": True,
                }
                for i, cls_key in enumerate(mock_picks)
            ]
        }

    # Real inference
    tensor = preprocess(image).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        logits = model(tensor)
        probs = torch.softmax(logits, dim=1)[0]

    top_probs, top_idxs = torch.topk(probs, min(TOP_K, num_classes))

    predictions = []
    for rank, (prob, idx) in enumerate(zip(top_probs.tolist(), top_idxs.tolist()), start=1):
        cls_key = idx_to_class.get(str(idx), str(idx))
        product_name = PH_GROCERY_MAP.get(cls_key, cls_key)
        predictions.append({
            "rank": rank,
            "class_id": cls_key,
            "product_name": product_name,
            "confidence": round(prob, 4),
        })

    return {"predictions": predictions}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
