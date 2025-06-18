from fastapi import APIRouter
from pydantic import BaseModel
import hashlib

router = APIRouter()

class TextRequest(BaseModel):
    text: str

class HashResponse(BaseModel):
    md5: str
    sha1: str
    sha256: str
    sha512: str
    success: bool
    error: str = None

@router.post("/generate")
async def generate_hashes(request: TextRequest):
    try:
        text_bytes = request.text.encode('utf-8')

        md5_hash = hashlib.md5(text_bytes).hexdigest()
        sha1_hash = hashlib.sha1(text_bytes).hexdigest()
        sha256_hash = hashlib.sha256(text_bytes).hexdigest()
        sha512_hash = hashlib.sha512(text_bytes).hexdigest()

        return HashResponse(
            md5=md5_hash,
            sha1=sha1_hash,
            sha256=sha256_hash,
            sha512=sha512_hash,
            success=True
        )
    except Exception as e:
        return HashResponse(
            md5="", sha1="", sha256="", sha512="",
            success=False, error=str(e)
        )