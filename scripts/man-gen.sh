#!/usr/bin/sh

# Generate man-pages using scdoc command

GREEN="\033[0;32m"
NC="\033[0m"

echo -e "Generating man pages:"
for file in "./doc/man/"*; do
    if [ "${file##*.}" == "scdoc" ]; then
        output="${file%.scdoc}"
        scdoc <$file >$output
        echo -e "  ${GREEN}=>${NC} $output"
    fi
done
echo -e "${GREEN}Done!${NC}"
