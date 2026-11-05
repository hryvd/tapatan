Place your product_model.tflite file in this directory.

To generate it, run from the project root:
  python convert_to_tflite.py

Requirements:
  pip install torch torchvision onnx onnx-tf tensorflow

This converts product_model.pth → ONNX → TFLite with dynamic quantization
and copies the result here automatically.
