from fastapi import APIRouter
from pydantic import BaseModel
import urllib.parse

router = APIRouter()

class TextRequest(BaseModel):
    text: str

class URLResponse(BaseModel):
    result: str
    success: bool
    error: str = None

@router.post("/encode")
async def encode_url(request: TextRequest):
    try:
        encoded = urllib.parse.quote(request.text, safe='')
        return URLResponse(result=encoded, success=True)
    except Exception as e:
        return URLResponse(result="", success=False, error=str(e))

@router.post("/decode")
async def decode_url(request: TextRequest):
    try:
        decoded = urllib.parse.unquote(request.text)
        return URLResponse(result=decoded, success=True)
    except Exception as e:
        return URLResponse(result="", success=False, error=str(e))