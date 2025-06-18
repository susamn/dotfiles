from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import base64

router = APIRouter()

class TextRequest(BaseModel):
    text: str

class Base64Response(BaseModel):
    result: str
    success: bool
    error: str = None

@router.post("/encode", response_model=Base64Response)
async def encode_base64(request: TextRequest):
    try:
        encoded = base64.b64encode(request.text.encode('utf-8')).decode('utf-8')
        return Base64Response(result=encoded, success=True)
    except Exception as e:
        return Base64Response(result="", success=False, error=str(e))

@router.post("/decode", response_model=Base64Response)
async def decode_base64(request: TextRequest):
    try:
        decoded = base64.b64decode(request.text).decode('utf-8')
        return Base64Response(result=decoded, success=True)
    except Exception as e:
        return Base64Response(result="", success=False, error=str(e))