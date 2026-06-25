#!/bin/sh

# Generate man-pages using scdoc command

GREEN="\033[0;32m"
NC="\033[0m"

echo -e "Generating man pages:"
for file in "./doc/man/"*; do
    if [ "${file##*.}" = "scdoc" ]; then
        output="${file%.scdoc}"
        scdoc <"$file" >"$output"
        printf "  ${GREEN}=>${NC} $output\n"
    fi
done
printf "${GREEN}Done!${NC}\n"
