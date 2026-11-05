"""
Convert product_model.pth → product_model.tflite
=================================================
Run this ONCE on your PC before building the APK.

Requirements:
  pip install torch torchvision onnx onnx-tf tensorflow

Steps performed:
  1. Load your trained MobileNetV3-Large from product_model.pth
  2. Export to ONNX (product_model.onnx)
  3. Convert ONNX → TF SavedModel → TFLite (product_model.tflite)
  4. Copy .tflite to Flutter assets/models/

Usage:
  python convert_to_tflite.py
"""

from __future__ import annotations
import shutil
import sys
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import models

# ── Paths ────────────────────────────────────────────────────────────────────
BASE   = Path(__file__).parent
PTH    = BASE / "product_model.pth"
ONNX   = BASE / "product_model.onnx"
TF_DIR = BASE / "product_model_tf"
TFLITE = BASE / "product_model.tflite"
ASSETS = BASE / "assets" / "models"

NUM_CLASSES = 41   # Must match training (0..40)
IMG_SIZE    = 224  # MobileNetV3 standard input

# ─────────────────────────────────────────────────────────────────────────────

def step1_load_model() -> nn.Module:
    print("[1/4] Loading PyTorch model from", PTH)
    if not PTH.exists():
        sys.exit(f"ERROR: {PTH} not found. Place product_model.pth here first.")
    m = models.mobilenet_v3_large(weights=None)
    m.classifier = nn.Sequential(
        nn.Linear(960, 512),
        nn.Hardswish(),
        nn.Dropout(p=0.2, inplace=True),
        nn.Linear(512, NUM_CLASSES)
    )
    checkpoint = torch.load(PTH, map_location="cpu")
    if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        m.load_state_dict(checkpoint["model_state_dict"])
    else:
        m.load_state_dict(checkpoint)
    m.eval()
    print("    Model loaded OK")
    return m


def step2_export_onnx(model: nn.Module) -> None:
    print("[2/4] Exporting to ONNX")
    dummy = torch.randn(1, 3, IMG_SIZE, IMG_SIZE)
    torch.onnx.export(
        model,
        dummy,
        str(ONNX),
        opset_version=13,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
        verbose=False,
    )
    print("    ONNX exported OK")


def step3_onnx_to_tflite() -> None:
    print("[3/4] Converting ONNX to TFLite")
    try:
        import onnx
        from onnx_tf.backend import prepare
        import tensorflow as tf

        # ONNX to TF SavedModel
        onnx_model = onnx.load(str(ONNX))
        tf_rep = prepare(onnx_model)
        tf_rep.export_graph(str(TF_DIR))
        print("    SavedModel written to", TF_DIR)

        # TF SavedModel to TFLite
        converter = tf.lite.TFLiteConverter.from_saved_model(str(TF_DIR))
        converter.optimizations = [tf.lite.Optimize.DEFAULT]  # dynamic quant
        tflite_model = converter.convert()
        TFLITE.write_bytes(tflite_model)
        print(f"    TFLite model: {TFLITE} ({TFLITE.stat().st_size // 1024} KB)")

    except ImportError as e:
        sys.exit(
            f"\nMissing dependency: {e}\n"
            "Install with:\n"
            "  pip install onnx onnx-tf tensorflow\n"
        )


def step4_copy_to_assets() -> None:
    print("[4/4] Copying to Flutter assets/models/")
    ASSETS.mkdir(parents=True, exist_ok=True)
    dest = ASSETS / "product_model.tflite"
    shutil.copy2(TFLITE, dest)
    print(f"    Copied to {dest}")
    print("\nConversion complete! Now run: flutter build apk --release")


if __name__ == "__main__":
    model = step1_load_model()
    step2_export_onnx(model)
    step3_onnx_to_tflite()
    step4_copy_to_assets()
