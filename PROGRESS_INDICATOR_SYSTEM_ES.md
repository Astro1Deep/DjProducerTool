# 🎨 Indicador de Progreso & Rueda Sistema
## Visual Feedback Architecture for DJProducerTools

**Version:** 1.0.0  
**Last Updated:** 2025-01-04  
**Purpose:** Ensure terminal always shows activity with colored ruedas and progress bars

---

## 📋 Table of Contents

1. [Sistema Overview](#sistema-overview)
2. [Rueda Specifications](#rueda-specifications)
3. [Progress Bar Implementation](#progress-bar-implementation)
4. [Color Schema](#color-schema)
5. [Module Assignments](#module-assignments)
6. [Implementation Examples](#implementation-examples)
7. [Troubleshooting](#troubleshooting)

---

## Sistema Overview

### Why Visual Feedback Matters

When running long-duration operations, users need **constant visual feedback** to know the sistema hasn't frozen. The DJProducerTools uses:

1. **Phantom Progress Bars** - Advance even when actual progress is unknown
2. **Colored Ruedas** - Module-specific indicators
3. **Status Messages** - Clear activity descriptions
4. **Time Estimates** - Projected completion times

### Architecture

```
┌─────────────────────────────────────────────┐
│     User Terminal Display (macOS)           │
├─────────────────────────────────────────────┤
│                                             │
│  [████████░░░░░░░░░░░░░░] 35%              │
│  💡 Initializing DMX controllers...        │
│  Estimated time: 2 minutes                  │
│                                             │
│  Messages:                                  │
│  ✅ Detected Art-Net device #1             │
│  ✅ Configured Universe 0                  │
│  ⏳ Waiting for Universe 1...              │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Rueda Specifications

### Rueda Types

#### Type 1: **Phantom Progress Rueda**
Used when total progress is unknown but operation is in progress.

```
Frame Sequence (repeating):
⠋ → ⠙ → ⠹ → ⠸ → ⠼ → ⠴ → ⠦ → ⠧ → ⠇ → ⠏ → (repeat)

Duration: 100ms per frame
Speed: 10 frames/second
```

#### Type 2: **Linear Progress Bar**
Realistic progress when duration is known.

```
[████████████░░░░░░░░░░░░░░░░░░] 40%

Blocks: ■ (filled) = 1/16 progress
        ░ (empty) = 1/16 remaining
Total width: 32 characters + label
```

#### Type 3: **Activity Rueda**
Rotating indicator for current operation.

```
Default sequence: ◐ ◓ ◑ ◒ (rotating circle)
Alternative: → ↘ ↓ ↙ ← ↖ ↑ ↗ (arrow rotation)
```

---

## Progress Bar Implementation

### Basic Progress Bar

```bash
progress_bar() {
    local current=$1
    local total=$2
    local width=32
    
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    
    # Create bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    local percent=$(( current * 100 / total ))
    
    printf "\r[%s] %d%%" "$bar" "$percent"
}
```

### Phantom Progress Bar

Used for unknown-duration operations. Gradually increases then resets:

```bash
phantom_progress() {
    local step=$1
    local width=32
    
    # Step increases 0→32→0→32 (simulates progress)
    local filled=$(( (step % 64) / 2 ))
    if [ $filled -gt $width ]; then
        filled=$(( width - (filled - width) ))
    fi
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<(width-filled); i++)); do bar+="░"; done
    
    # Estimate completion (fake, but prevents appearance of frozen)
    local fake_percent=$(( (step % 64) * 100 / 64 ))
    
    printf "\r[%s] ~%d%%" "$bar" "$fake_percent"
}
```

---

## Color Schema

### ANSI Color Codes

```bash
# Basic Colors
RED='\033[0;31m'          # Errors
GREEN='\033[0;32m'        # Success
YELLOW='\033[1;33m'       # Warnings
BLUE='\033[0;34m'         # Headers
CYAN='\033[0;36m'         # Info/Default
WHITE='\033[0;37m'        # Text
MAGENTA='\033[0;35m'      # Special

# Bright Colors
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_CYAN='\033[1;36m'
BRIGHT_MAGENTA='\033[1;35m'

# Background Colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'
BG_CYAN='\033[46m'

# Reset
NC='\033[0m'  # No Color
```

### Font Styles

```bash
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'
```

---

## Module Assignments

### Module-Specific Ruedas & Colors

#### 🔊 AUDIO MODULE
```
Rueda: 🔊 🎵  🎶
Colors: Cyan/Blue
Frame Rate: 10 FPS
Usage: Audio normalization, BPM analysis, file processing
```

#### 💡 DMX/LIGHTING MODULE
```
Rueda: 💡 ⚡ 🔆
Colors: Purple/Magenta
Frame Rate: 8 FPS (slower for precise lighting)
Usage: DMX initialization, fixture control, effect sequencing
```

#### 📡 OSC CONTROL MODULE
```
Rueda: 📡 🛰️ 📶
Colors: Green/Lime
Frame Rate: 12 FPS (responsive for network)
Usage: OSC server setup, message routing, diagnostics
```

#### 🎬 VIDEO INTEGRATION MODULE
```
Rueda: 🎬 🎥 📹
Colors: Red/Orange
Frame Rate: 8 FPS (matches video frame timing)
Usage: Video sync, metadata extraction, Serato integration
```

#### 📚 LIBRARY MANAGEMENT MODULE
```
Rueda: 📚 📖 📕
Colors: Yellow/Gold
Frame Rate: 10 FPS
Usage: Library organization, metadata cleanup, import/export
```

#### ⚙️ SYSTEM DIAGNOSTICS MODULE
```
Rueda: ⚙️ 🔧 🔨
Colors: Gray/White
Frame Rate: 10 FPS
Usage: Sistema health, performance metrics, logging
```

#### 🔁 BATCH OPERATIONS MODULE
```
Rueda: 🔁 ♻️ 🔄
Colors: Cyan/Blue
Frame Rate: 10 FPS
Usage: Parallel processing, queue management, bulk operations
```

---

## Implementation Examples

### Example 1: Simple Progress Bar with Rueda

```bash
#!/bin/bash

SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# DMX initialization with progress tracking
dmx_init() {
    local total_steps=100
    
    echo "Starting DMX initialization..."
    
    for i in {1..100}; do
        # Display rueda with module-specific color
        local rueda_index=$(( i % 10 ))
        local rueda="${SPINNER_CHARS[$rueda_index]}"
        
        # Calculate progress
        local filled=$(( i * 32 / total_steps ))
        local bar=""
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=filled; j<32; j++)); do bar+="░"; done
        
        # Display with appropriate color for DMX module
        printf "\r${MAGENTA}${rueda}${NC} [%s] %d%% | 💡 Initializing DMX..." "$bar" "$i"
        
        # Simulate work
        sleep 0.01
    done
    
    printf "\r${MAGENTA}✅${NC} [████████████████████████████████] 100%% | 💡 DMX Ready\n"
}

dmx_init
```

### Example 2: Phantom Progress with Messages

```bash
#!/bin/bash

SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

bpm_analyze() {
    local file="$1"
    local step=0
    
    echo "Analyzing BPM for: $file"
    
    # Simulate long-running operation with phantom progress
    for i in {1..50}; do
        local rueda_index=$(( step % 10 ))
        
        # Phantom progress (increases then resets)
        local phantom=$(( (step % 64) / 2 ))
        if [ $phantom -gt 32 ]; then
            phantom=$(( 32 - (phantom - 32) ))
        fi
        
        local bar=""
        for ((j=0; j<phantom; j++)); do bar+="█"; done
        for ((j=phantom; j<32; j++)); do bar+="░"; done
        
        printf "\r${CYAN}${SPINNER_CHARS[$rueda_index]}${NC} [%s] ~%d%% | 🔊 Analyzing BPM..." "$bar" "$((phantom*3))"
        
        sleep 0.1
        step=$((step + 1))
    done
    
    # Show completion
    printf "\r${GREEN}✅${NC} [████████████████████████████████] 100%% | 🔊 BPM Analysis Complete\n"
    echo "${GREEN}✅ Detected BPM: 128.5 (95% confidence)${NC}"
}

bpm_analyze "song.mp3"
```

### Example 3: Multi-Stage Progress with Sub-messages

```bash
#!/bin/bash

MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

dmx_fixtures() {
    echo "Setting up DMX fixtures..."
    echo ""
    
    # Stage 1: Scan for devices
    for i in {1..30}; do
        local filled=$(( i * 32 / 30 ))
        local bar=""
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=filled; j<32; j++)); do bar+="░"; done
        
        printf "\r${MAGENTA}[%s] %d%%%% | 💡 Scanning for devices...${NC}" "$bar" "$((i*100/30))"
        sleep 0.05
    done
    printf "\r${GREEN}✅${NC} [████████████████████████████████] 100%% | 💡 Scanning complete\n"
    echo "${GREEN}✅ Found 2 Art-Net devices${NC}"
    echo ""
    
    # Stage 2: Initialize devices
    for i in {1..40}; do
        local filled=$(( i * 32 / 40 ))
        local bar=""
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=filled; j<32; j++)); do bar+="░"; done
        
        printf "\r${MAGENTA}[%s] %d%%%% | 💡 Initializing fixtures...${NC}" "$bar" "$((i*100/40))"
        sleep 0.05
    done
    printf "\r${GREEN}✅${NC} [████████████████████████████████] 100%% | 💡 Fixtures initialized\n"
    echo "${GREEN}✅ Configured 24 moving heads${NC}"
    echo ""
}

dmx_fixtures
```

---

## Troubleshooting

### Issue: Rueda Not Animating

**Cause:** Output buffering or tput limitations  
**Solution:**
```bash
# Ensure unbuffered output
stdbuf -oL your_command

# Or use:
export PYTHONUNBUFFERED=1
```

### Issue: Colors Not Displaying

**Cause:** Terminal doesn't support ANSI colors  
**Solution:**
```bash
# Check terminal capabilities
echo $TERM

# Force 256-color mode
export TERM=screen-256color

# Verify color support
tput colors  # Should output 256 or higher
```

### Issue: Rueda "Freezes"

**Cause:** Background process completed but rueda still running  
**Solution:**
```bash
# Always kill rueda on completion
kill $rueda_pid 2>/dev/null
wait $rueda_pid 2>/dev/null

# Clear the line
printf "\r\033[K"
```

### Issue: Progress Bar Doesn't Align

**Cause:** Unicode character width calculation  
**Solution:**
```bash
# Use printf length calculation
bar_length=$( printf "%s" "$bar" | wc -c )

# Account for emoji width (may be counted as 2)
# Use fixed-width ruedas for consistency
```

---

## Best Practices

### ✅ DO

- ✅ Show rueda for ANY operation > 1 second
- ✅ Update every 100-200ms (10 FPS)
- ✅ Use module-specific colors consistently
- ✅ Display completion message with checkmark
- ✅ Show time elapsed and remaining estimate
- ✅ Handle Ctrl+C gracefully (clean up rueda)

### ❌ DON'T

- ❌ Don't use progress bar without actual progress tracking
- ❌ Don't update rueda faster than 20 FPS (CPU intensive)
- ❌ Don't mix rueda types in same operation
- ❌ Don't forget to reset terminal color (NC)
- ❌ Don't hide errors behind progress bar
- ❌ Don't make rueda thread non-killable

---

## Testing Your Implementation

```bash
# Test rueda animación
while true; do
    for rueda in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do
        printf "\r%s" "$rueda"
        sleep 0.1
    done
done

# Test progress bar
for i in {1..100}; do
    filled=$(( i * 32 / 100 ))
    bar=""
    for ((j=0; j<filled; j++)); do bar+="█"; done
    for ((j=filled; j<32; j++)); do bar+="░"; done
    printf "\r[%s] %d%%" "$bar" "$i"
    sleep 0.05
done
echo ""
```

---

**This sistema ensures DJProducerTools ALWAYS provides visual feedback, preventing users from wondering if the sistema has frozen.** 🎨✨

