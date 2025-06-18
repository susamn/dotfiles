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
    line_number1: int = None
    line_number2: int = None

class DiffResponse(BaseModel):
    diff: List[DiffLine]
    success: bool
    error: str = None

@router.post("/compare")
async def compare_texts(request: DiffRequest):
    try:
        text1_lines = request.text1.splitlines()
        text2_lines = request.text2.splitlines()

        differ = difflib.unified_diff(
            text1_lines,
            text2_lines,
            lineterm='',
            n=3
        )

        diff_result = []
        line_num1 = 0
        line_num2 = 0

        for line in differ:
            if line.startswith('@@'):
                continue
            elif line.startswith('---') or line.startswith('+++'):
                continue
            elif line.startswith('-'):
                diff_result.append(DiffLine(
                    type='delete',
                    content=line[1:],
                    line_number1=line_num1,
                    line_number2=None
                ))
                line_num1 += 1
            elif line.startswith('+'):
                diff_result.append(DiffLine(
                    type='insert',
                    content=line[1:],
                    line_number1=None,
                    line_number2=line_num2
                ))
                line_num2 += 1
            else:
                diff_result.append(DiffLine(
                    type='equal',
                    content=line[1:] if line.startswith(' ') else line,
                    line_number1=line_num1,
                    line_number2=line_num2
                ))
                line_num1 += 1
                line_num2 += 1

        return DiffResponse(diff=diff_result, success=True)
    except Exception as e:
        return DiffResponse(diff=[], success=False, error=str(e))