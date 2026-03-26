#!/usr/bin/env bash

SOURCE_DIR=configurations
CONFIG_DIR=src/Configuration

if [[ ! "$1" =~ ^([0-9a-zA-Z\_]+(,[0-9a-zA-Z\_]+)*)?$ ]]; then
    echo "Configuration list is not a comma-separated list!"
    exit 1
fi

rm -f $CONFIG_DIR/_components_
touch $CONFIG_DIR/_components_

# Copy base configuration, this should always be present
echo "Copying base configuration"
({ set -x; } 2>/dev/null; cp "$SOURCE_DIR/PlatformVersion.st" "$CONFIG_DIR/")
({ set -x; } 2>/dev/null; cp "$SOURCE_DIR/base"/*.st "$CONFIG_DIR/")

IFS=',' read -ra configurations <<< "$1"
for config in "${configurations[@]}"; do
  config="$(echo "$config" | xargs)" # Trim whitespace
  if [ -d "$SOURCE_DIR/$config" ]; then
    echo "Copying $config configuration"
    ({ set -x; } 2>/dev/null; cp "$SOURCE_DIR/$config"/*.st "$CONFIG_DIR/")

    if [ -f "$SOURCE_DIR/$config/_components_" ] ; then
        cat "$SOURCE_DIR/$config/_components_" >> "$CONFIG_DIR/_components_"
        echo "," >> "$CONFIG_DIR/_components_"
    fi
  else
    echo "$config is not a directory in '$SOURCE_DIR/', exiting!"
    exit 1
  fi
done

({ set -x; } 2>/dev/null; chmod -R a-w "$CONFIG_DIR"/*.st)

# The file is now in several rows, transform it to single line CSV
if [ -f "$CONFIG_DIR/_components_" ] ; then
    sed -i 's/^/,/' "$CONFIG_DIR/_components_"
    tr -d '\n' < "$CONFIG_DIR/_components_" > "$CONFIG_DIR/_components_tmp"
    mv "$CONFIG_DIR/_components_tmp" "$CONFIG_DIR/_components_"
    sed -E -i 's/[[:space:]]+//' "$CONFIG_DIR/_components_"
    sed -E -i 's/^,+//' "$CONFIG_DIR/_components_"
    sed -E -i 's/,+$//' "$CONFIG_DIR/_components_"
    sed -E -i 's/,,+/,/' "$CONFIG_DIR/_components_"
fi

({ set -x; } 2>/dev/null; chmod a-w "$CONFIG_DIR/_components_")

if [[ ! $(cat "$CONFIG_DIR/_components_") =~ ^([0-9a-zA-Z\_]+(,[0-9a-zA-Z\_]+)*)?$ ]]; then
    echo "Components list is not a comma-separated list!"
    exit 1
fi
