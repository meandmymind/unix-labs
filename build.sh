#! /usr/bin/sh


# Exit codes
OK=0
BAD_ARGUMENTS=1
COMPILER_NOT_FOUND=2
OUTPUT_NAME_NOT_FOUND=3


function find_output_name {
    # Describe regex by parts
    # Example: "    //   output: hello     "
    comment_sign_before_payload="^[[:space:]]*\/\/[[:space:]]*"
    output_keyword="output:"
    whitespace_before_filename="[[:space:]]*"
    output_filename="([^[:space:]]+)"  # 1+ non-whitespace characters
    whitespace_after_filename="[[:space:]]*$"  # till the end of line

    # Combine parts of regex
    full_regex=$comment_sign_before_payload$output_keyword$whitespace_before_filename
    full_regex=$full_regex$output_filename$whitespace_before_filename

    # Find the first occurence of pattern in src file
    matched_lines=$(
        grep --no-filename --only-matching --extended-regexp $full_regex filename
    )
    first_match_only=$(echo "$matched_lines" | head -1)

    # Use sed to get only capture group because grep can't
    output_name=$(
        echo $first_match_only | sed --regexp-extended "s/$full_regex/\1/"
    )

    echo $output_name
}


# Define some utils
function clean_up_and_exit() {
    echo "Cleaning up temp files"

    temp_dir=$1
    exit_code=$2

    rm -rf $temp_dir
    echo "Done"

    exit $exit_code
}


function main() {
    # Ensure stop signals are correctly handled
    temp_dir=$(mktemp -d)
    trap "clean_up_and_exit $temp_dir $OK" SIGINT SIGTERM SIGKILL

    # Define constants
    src_file="$1" 
    src_dir="$(dirname $src_file)"
    src_basename="$(basename $src_file)"

    # Parse src file and find output filename
    output_name=$(find_output_name "$src_file")
    if [ -z "$output_name" ]
    then
        echo "Failed to parse output name." >&2
        exit $OUTPUT_NAME_NOT_FOUND
    fi
    output_file="$src_dir/$output_name"

    # Copy src to temp_dir
    temp_src_file="$temp_dir/$src_file"
    temp_output_file="$temp_dir/$output_name"
    cp "$src_file" "$temp_src_file"

    # Build
    rustc "$temp_src_file" -o "$temp_output_file"

    if [ $? -eq $OK ]
    then
        cp "$temp_output_file" "$output_file"
        echo "Compilation finished."
        echo "Compiled file: "$output_file""
        exit_code=$OK
    else
        echo "Compilation failed." >&2
        exit_code=$COMPILATION_FAILED
    fi

    clean_up_and_exit "$temp_dir" $exit_code
}


function check_compiler_exists() {
    # Check that compiler exists
    which rustc > /dev/null  # Don't write to stdout 
    
    if [ $? -eq 1 ]
    then
        echo "rustc compiler not found"
        exit $COMPILER_NOT_FOUND
    fi
}


function check_input_file() {
    # Surround with quotes, as filename can have whitespaces in it. How convenient.
    filename="$1"

    if [ ! -f "$filename" ] 
    then
        echo "First arg must be valid path to a source code file." >&2
        exit $BAD_ARG

    elif [ ! -r "$filename" ]
    then
        echo "Source code file must be readable." >&2
        exit $BAD_ARG

    elif [ ! -w $(dirname "$filename") ]
    then
        echo "Source code directory must be writable." >&2
        exit $BAD_ARG    
    fi
}


# Check arguments
if [ $# -ne 1 ]
then
    echo "Give exactly one argument. For example: ./build.sh src/main.rs"
    exit $BAD_ARG
fi

src_file="$1"
check_input_file "$src_file"

check_compiler_exists

main "$src_file"
