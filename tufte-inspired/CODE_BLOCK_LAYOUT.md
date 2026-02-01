# Automatic Code Block Layout

The Tufte-inspired template now supports automatic detection and layout of code blocks based on their content.

## YAML Configuration

Add to your document's YAML header:

```yaml
---
code-block-layout: auto  # auto|manual|wide|normal
code-max-line-length: 60  # Optional: threshold for triggering wide layout
code-min-lines-for-wide: 15  # Optional: minimum lines to trigger wide layout
---
```

## Layout Modes

### `auto` (default)
Automatically detects whether code blocks need wide layout based on:
- **Line length**: If any line exceeds `code-max-line-length` (default: 60 characters)
- **Block size**: If total lines exceed `code-min-lines-for-wide` (default: 15 lines)

Code blocks meeting either criterion are automatically wrapped in `.wideblock` for wider display.

### `manual`
Requires explicit class assignment. Only code blocks with `.wideblock` class will be wide:

```markdown
::: {.wideblock}
```python
# This will be wide
very_long_line_of_code_that_would_otherwise_wrap_awkwardly = some_function()
```
:::
```

### `wide`
Forces ALL code blocks to use wide layout (fullwidth):

```yaml
code-block-layout: wide
```

### `normal`
Forces ALL code blocks to use normal (main body) width:

```yaml
code-block-layout: normal
```

## Examples

### Auto mode with custom thresholds

```yaml
---
code-block-layout: auto
code-max-line-length: 80  # Wider threshold
code-min-lines-for-wide: 20  # Longer blocks before going wide
---
```

### Manual control

```yaml
---
code-block-layout: manual
---

Regular code block:
```python
short = "stays in main body"
```

Wide code block:
::: {.wideblock}
```python
very_long_function_call_with_many_parameters(arg1, arg2, arg3, arg4, arg5)
```
:::
```

## How It Works

1. The Lua filter (`margin_references.lua`) processes all `CodeBlock` elements
2. Based on `code-block-layout` setting:
   - **auto**: Analyzes line lengths and block size
   - **manual**: Only wraps if `.wideblock` class present
   - **wide/normal**: Forces all blocks to that layout
3. Qualifying code blocks are wrapped in a `Div` with class `.wideblock`
4. The `.wideblock` Div handler applies Typst's wide block formatting

## Typst Output

Wide code blocks are rendered with:
```typst
#block(width: 100%+75.2mm)[
  // code content
]
```

This matches the fullwidth environment, extending into the margin area.
