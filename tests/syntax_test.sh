#!/bin/bash
# Test script to isolate syntax issues

# Basic color definitions
C_GRN='\033[1;32m'
C_CYN='\033[1;36m'
C_RESET='\033[0m'

# Test functions
test_function() {
  echo "Test function"
  printf "%s[INFO]%s Test message\n" "$C_CYN" "$C_RESET"
}

# Main test
echo "Testing syntax..."
test_function
echo "Syntax test completed"
