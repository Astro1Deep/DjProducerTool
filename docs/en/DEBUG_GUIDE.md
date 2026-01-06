# DJProducerTools - Debugging & Progress Guide

## Overview

All script options now include:
- ✅ **Progress bars** showing percentage and time estimates
- ✅ **Ghost spinners** animating while processing
- ✅ **Real-time status updates** so you always know it's not frozen
- ✅ **Debug mode** for deep introspection
- ✅ **Execution timing** for performance optimization
- ✅ **Step-by-step tracking** for complex operations

## Running with Debug Output

### Enable Debug Mode

```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_EN.sh
```

This will show:
- Function entry/exit points with code names
- Exact timing for each operation
- Variable states and intermediate values
- Full command traces
- Resource usage warnings

### Debug Levels

| Level | Symbol | When Used | Example |
|-------|--------|-----------|---------|
| INFO | ℹ | General information | Starting operation |
| SUCCESS | ✓ | Successful completion | Hash index generated |
| WARN | ⚠ | Warnings | Low disk space |
| ERROR | ✗ | Error conditions | File not found |
| DEBUG | ⚙ | Development info | Variable values |

## Progress Indicators

### Progress Bars

During long operations, you'll see:
```
Progress: ████████░░░░░░░░░░░░░░░░░░░░░░ 33% [1000/3000] (45s elapsed, ~90s remaining)
```

Breaking it down:
- **Visual bar**: Filled (█) vs empty (░) blocks
- **Percentage**: 0-100%
- **Count**: Current/Total items
- **Time**: Elapsed and estimated remaining

### Ghost Spinners

While processing without individual items:
```
◐ Scanning library...   
◓ Scanning library...
◑ Scanning library...
◒ Scanning library...
```

These rotate continuously, proving the tool is working even with no progress to display.

### Multi-Step Operations

For complex workflows:
```
▶ Step 1/5: Initializing workspace
✓ Step 1/5 complete
▶ Step 2/5: Scanning files
✓ Step 2/5 complete
```

## Using with Specific Options

### Option 1: Status Check (with debug)
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_EN.sh --option 1
```
Output:
```
[08:30:15] ℹ Starting Status Check
[08:30:15] ⚙ → Entering: check_paths()
[08:30:15] ⚙ Loading configuration from /path/to/djpt.conf
[08:30:16] ✓ Configuration loaded successfully (1.2ms)
[08:30:16] ⚙ ← Exiting: check_paths() [code: 0]
```

### Option 9: Hash Index (with progress)
```bash
./DJProducerTools_MultiScript_EN.sh --option 9
```
Output:
```
▶ Step 1/3: Scanning files
ℹ Found 2,345 audio files
Hashing: ████████████░░░░░░░░░░░░░░░░░░░░░ 45% [1050/2345] (120s elapsed, ~145s remaining)
```

### Option 10: Find Duplicates (with debug + progress)
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_EN.sh --option 10
```
Shows:
- Each hash comparison with status
- Duplicate groups being identified
- Final statistics
- All in real-time

### Option 27: Snapshot (simple spinner)
```bash
./DJProducerTools_MultiScript_EN.sh --option 27
```
Output:
```
◐ Creating integrity snapshot...
◓ Creating integrity snapshot...
[08:35:20] ✓ Snapshot created: integrity_2024-01-04.json
```

## Performance Profiling

All operations with timing enabled show:

```
[08:40:00] ℹ Starting scan_workspace...
[08:40:15] ✓ scan_workspace completed in 15234.567ms
```

Use this to identify bottlenecks:
- Hash operations: Usually 5-20ms per file
- File I/O: Usually 1-10ms per operation
- Metadata reads: Usually 2-5ms per file

## Memory Warnings

When available memory drops below 500MB:
```
[08:45:30] ⚠ Low memory: 350MB available (threshold: 500MB)
```

This indicates:
- Library scan might slow down
- Large file processing might fail
- Consider closing other applications

## Troubleshooting with Debug

### Script Appears Frozen

When you see NO progress for >5 seconds:
1. Check with `DEBUG_MODE=1` to see current operation
2. Look for error messages in red
3. Press CTRL+C to stop and review logs

### Slow Performance

With timing data, you can see which step is slow:
```
[08:50:00] ℹ Starting hash_calculation...
[08:50:45] ✓ hash_calculation completed in 45000ms  ← TOO SLOW!
```

Solutions:
- Reduce file count with filters
- Increase available RAM
- Close competing applications

### Memory Errors

If you see:
```
[08:55:00] ⚠ Low memory: 100MB available
[08:55:05] ✗ Operation failed: Out of memory
```

Then:
- Restart script
- Close browser/other apps
- Reduce scope (fewer files)

## Log Files

All detailed debug output is also saved:

```
_DJProducerTools/logs/debug_YYYY-MM-DD.log
```

View with:
```bash
tail -f _DJProducerTools/logs/debug_*.log
```

## Advanced Debugging

### Trace Specific Function

Edit script to add:
```bash
trace_function "my_function_name" arg1 arg2
my_function_name arg1 arg2
trace_exit "my_function_name" $?
```

### Profile Section

Wrap any code section:
```bash
time_function "description" ./script_section.sh
```

### Resource Check

Before operations:
```bash
check_resources 1000  # Check for 1GB available
```

## Examples

### Fast Operation (Good)
```
◐ Comparing hashes...   
[08:50:00] ✓ Completed in 2.3ms
```

### Slow Operation (Warning)
```
Comparing: ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 15% [150/1000] (30s elapsed, ~170s remaining)
```

### Failed Operation (Error)
```
[08:55:00] ✗ Operation failed: Permission denied
[08:55:00] → Last function: process_files
[08:55:00] → Current file: /restricted/path/music.mp3
```

---

## Summary

- **Always visible output**: Never wonder if it's frozen
- **Progress bars**: Know how long remaining
- **Debug mode**: Deep inspection when needed
- **Timing data**: Identify bottlenecks
- **Warning system**: Get notified of problems early

Combine these features for complete visibility into all operations!
