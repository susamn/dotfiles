from fastapi import APIRouter
from pydantic import BaseModel
import difflib
from typing import List

router = APIRouter()

class DiffRequest(BaseModel):
    text1: str
    text2: str

class DiffLine(BaseModel):
    type: str  # 'equal', 'delete', 'insert'
    content: str

class DiffResponse(BaseModel):
    diff: List[DiffLine]
    success: bool
    error: str = None

@router.post("/compare")
async def compare_texts(request: DiffRequest):
    try:
        text1_lines = request.text1.splitlines()
        text2_lines = request.text2.splitlines()

        # Create side-by-side comparison using SequenceMatcher
        matcher = difflib.SequenceMatcher(None, text1_lines, text2_lines)
        diff_result = []

        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag == 'equal':
                for i in range(i1, i2):
                    diff_result.append(DiffLine(
                        type='equal',
                        content=text1_lines[i]
                    ))
            elif tag == 'delete':
                for i in range(i1, i2):
                    diff_result.append(DiffLine(
                        type='delete',
                        content=text1_lines[i]
                    ))
            elif tag == 'insert':
                for j in range(j1, j2):
                    diff_result.append(DiffLine(
                        type='insert',
                        content=text2_lines[j]
                    ))
            elif tag == 'replace':
                # Handle replacements by showing deletions first, then insertions
                for i in range(i1, i2):
                    diff_result.append(DiffLine(
                        type='delete',
                        content=text1_lines[i]
                    ))
                for j in range(j1, j2):
                    diff_result.append(DiffLine(
                        type='insert',
                        content=text2_lines[j]
                    ))

        return DiffResponse(diff=diff_result, success=True)
    except Exception as e:
        return DiffResponse(diff=[], success=False, error=str(e))