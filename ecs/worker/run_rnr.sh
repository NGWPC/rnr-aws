#!/bin/bash
# run_rnr.sh - Runs T-Route based on the HML files and generates output .nc files

# Default values
DETACH=false
NUM_HML_FILES=""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --num-hml-files NUMBER    Number of HML files to process (optional)"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Process all HML files in queue"
    echo "  $0 -n 5                      # Process only 5 HML files"
    echo "  $0 --num-hml-files 10        # Process only 10 HML files"
}

# Function to handle termination
cleanup() {
    echo "Stopping container process..."
    docker exec docker-rnr-1 bash -c "pkill -f 'python main.py'"
    echo "Process terminated"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--num-hml-files)
            NUM_HML_FILES="$2"
            if ! [[ "$NUM_HML_FILES" =~ ^[0-9]+$ ]]; then
                echo "Error: --num-hml-files must be a positive integer"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Build the command to run
PYTHON_CMD="source ../../.venv/bin/activate && python main.py"

# Add the num-hml-files argument if specified
if [[ -n "$NUM_HML_FILES" ]]; then
    PYTHON_CMD="$PYTHON_CMD --num-hml-files $NUM_HML_FILES"
    echo "Processing $NUM_HML_FILES HML files..."
else
    echo "Processing all HML files in queue..."
fi

# Set up signal handling for Ctrl+C
trap cleanup SIGINT SIGTERM

# Run in foreground with proper signal handling
echo "Running in console (Ctrl+C will properly terminate the process)"
docker exec docker-rnr-1 bash -c "$PYTHON_CMD"
