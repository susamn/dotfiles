---
name: media-tagger
description: Batch update media file metadata (tags) using ffmpeg. Use when needing to update artist, album, or other ID3 tags for multiple files.
version: 1.0.0
triggers:
  - "update media tags"
  - "batch tag songs"
  - "update artist metadata"
intent: media
resources:
  - $SCRIPTS_PATH/batch-tagger.py
tools:
  - ffmpeg
  - python3
interface:
  input:
    directory: "string — Path to the directory containing media files"
    mapping: "json — A mapping of filenames to tag dictionaries or artist strings"
---

# Media Tagger Skill

This skill allows for efficient batch updating of media file metadata (especially .m4a and .mp3) using ffmpeg.

## Workflow

1. **Identify Files:** Locate the media files and determine the correct metadata (e.g., via web search or iTunes).
2. **Create Mapping:** Prepare a JSON structure where keys are filenames and values are dictionaries of tags.
   \`\`\`json
   {
     "song1.m4a": {"artist": "Artist Name", "album": "Album Name"},
     "song2.m4a": "Artist Name"
   }
   \`\`\`
3. **Execute Update:** Use the \`batch-tagger.py\` script to apply the changes.

## Commands

\`\`\`bash
python3 \$SCRIPTS_PATH/batch-tagger.py /path/to/media mapping.json
\`\`\`

## Guardrails
- Always use \`-c copy\` with ffmpeg to avoid re-encoding.
- Verify file existence before attempting to update.
- Use temporary files to prevent data loss on failure.
