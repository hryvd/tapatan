import torch
import torch.nn as nn
from torchvision import models
from pathlib import Path

PTH = Path("product_model.pth")
ONNX = Path("product_model.onnx")
NUM_CLASSES = 41
IMG_SIZE = 224

print("Loading PyTorch model...")
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
print("Model loaded.")

print("Exporting to ONNX...")
dummy = torch.randn(1, 3, IMG_SIZE, IMG_SIZE)
torch.onnx.export(
    m,
    dummy,
    str(ONNX),
    opset_version=13,
    input_names=["input"],
    output_names=["output"],
    verbose=False,
)
print("ONNX exported successfully!")
