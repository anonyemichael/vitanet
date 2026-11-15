"""
VitaNet Legacy v1 Compatibility Stub.

NOTE: This module is part of the deprecated v1 ML prototype.
The implementation has moved to `ml-service/legacy_v1/app/predict.py`.
Active model development is located in `ml-service/new_model/`.
"""
import sys
import warnings
from pathlib import Path

# Add legacy_v1/app to sys.path
legacy_app_dir = Path(__file__).parent.parent / "legacy_v1" / "app"
if str(legacy_app_dir) not in sys.path:
    sys.path.insert(0, str(legacy_app_dir))

warnings.warn(
    "ml-service/app/predict.py is deprecated. Use ml-service/legacy_v1/app/predict.py instead.",
    DeprecationWarning,
    stacklevel=2
)

from predict import *

if __name__ == "__main__":
    import predict
    if hasattr(predict, "main"):
        predict.main()
