"""
VitaNet Legacy v1 Compatibility Stub.

NOTE: This FastAPI app is part of the deprecated v1 ML prototype.
The implementation has moved to `ml-service/legacy_v1/app/main.py`.
Active model development is located in `ml-service/new_model/`.
"""
import sys
import warnings
from pathlib import Path

legacy_app_dir = Path(__file__).parent.parent / "legacy_v1" / "app"
if str(legacy_app_dir) not in sys.path:
    sys.path.insert(0, str(legacy_app_dir))

warnings.warn(
    "ml-service/app/main.py is deprecated. Use ml-service/legacy_v1/app/main.py instead.",
    DeprecationWarning,
    stacklevel=2
)

from main import app  # noqa: F401
