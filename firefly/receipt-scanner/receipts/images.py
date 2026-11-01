"""Turn whatever the phone sends (HEIC, PNG, huge JPEG) into a small JPEG."""

from __future__ import annotations

import io

from PIL import Image, ImageOps

try:  # iPhone photos are often HEIC
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:  # pragma: no cover
    pass

# Claude reads images up to about this size on the long edge without
# downscaling; anything bigger only costs more.
MAX_EDGE = 1568
MAX_UPLOAD_BYTES = 20 * 1024 * 1024


class BadImage(ValueError):
    pass


def normalize(data: bytes) -> bytes:
    """Return a JPEG no larger than MAX_EDGE on its long side, upright."""
    if not data:
        raise BadImage("The upload was empty.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise BadImage("That image is over 20 MB.")
    try:
        img = Image.open(io.BytesIO(data))
        img = ImageOps.exif_transpose(img)
    except Exception as exc:  # Pillow raises many types
        raise BadImage("That file doesn't look like an image.") from exc
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    img.thumbnail((MAX_EDGE, MAX_EDGE))
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=85)
    return out.getvalue()
