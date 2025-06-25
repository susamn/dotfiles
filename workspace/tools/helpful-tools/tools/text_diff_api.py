from fastapi import APIRouter
from pydantic import BaseModel
import difflib
from typing import List, Optional

router = APIRouter()

class DiffRequest(BaseModel):
    text1: str
    text2: str

class CharDiff(BaseModel):
    type: str  # 'equal', 'delete', 'insert'
    content: str

class DiffLine(BaseModel):
    type: str  # 'equal', 'delete', 'insert', 'replace'
    content: str
    char_diff: Optional[List[CharDiff]] = None
    original_content: Optional[str] = None  # For replace type

class DiffResponse(BaseModel):
    diff: List[DiffLine]
    success: bool
    error: str = None

def get_character_diff(old_text: str, new_text: str) -> List[CharDiff]:
    """Generate character-level diff between two strings."""
    matcher = difflib.SequenceMatcher(None, old_text, new_text)
    char_diffs = []
    
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == 'equal':
            char_diffs.append(CharDiff(
                type='equal',
                content=old_text[i1:i2]
            ))
        elif tag == 'delete':
            char_diffs.append(CharDiff(
                type='delete',
                content=old_text[i1:i2]
            ))
        elif tag == 'insert':
            char_diffs.append(CharDiff(
                type='insert',
                content=new_text[j1:j2]
            ))
        elif tag == 'replace':
            # For replace, show deletion first, then insertion
            if i1 < i2:
                char_diffs.append(CharDiff(
                    type='delete',
                    content=old_text[i1:i2]
                ))
            if j1 < j2:
                char_diffs.append(CharDiff(
                    type='insert',
                    content=new_text[j1:j2]
                ))
    
    return char_diffs

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
                # Handle replacements with character-level diffs
                old_lines = text1_lines[i1:i2]
                new_lines = text2_lines[j1:j2]
                
                # If we have the same number of lines, do character-level diff
                if len(old_lines) == len(new_lines) == 1:
                    char_diff = get_character_diff(old_lines[0], new_lines[0])
                    diff_result.append(DiffLine(
                        type='replace',
                        content=new_lines[0],
                        original_content=old_lines[0],
                        char_diff=char_diff
                    ))
                else:
                    # Fallback to line-level diff for complex replacements
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