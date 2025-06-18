from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import qrcode
import io

router = APIRouter()

class QRRequest(BaseModel):
    text: str
    size: int = 10
    border: int = 4

@router.post("/generate")
async def generate_qr(request: QRRequest):
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=request.size,
            border=request.border,
        )
        qr.add_data(request.text)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        img_io = io.BytesIO()
        img.save(img_io, 'PNG')
        img_io.seek(0)

        return StreamingResponse(img_io, media_type="image/png")
    except Exception as e:
        return {"success": False, "error": str(e)}