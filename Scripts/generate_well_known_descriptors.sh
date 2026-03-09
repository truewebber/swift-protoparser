#!/bin/bash
# Regenerates the reference binary descriptor files used by WellKnownTypesIntegrationTests.
#
# Run from the repository root:
#   ./Scripts/generate_well_known_descriptors.sh
#
# Requires protoc to be installed. The well-known .proto files are expected at
# /usr/local/include/google/protobuf/ (standard homebrew protobuf install).

set -euo pipefail

PROTO_PATH="${PROTO_PATH:-/usr/local/include}"
OUTPUT_DIR="Tests/TestResources/WellKnownDescriptors"

mkdir -p "$OUTPUT_DIR"

PROTOS=(
  "google/protobuf/any.proto"
  "google/protobuf/api.proto"
  "google/protobuf/descriptor.proto"
  "google/protobuf/duration.proto"
  "google/protobuf/empty.proto"
  "google/protobuf/field_mask.proto"
  "google/protobuf/source_context.proto"
  "google/protobuf/struct.proto"
  "google/protobuf/timestamp.proto"
  "google/protobuf/type.proto"
  "google/protobuf/wrappers.proto"
)

for proto in "${PROTOS[@]}"; do
  name=$(basename "$proto" .proto)
  protoc \
    --proto_path="$PROTO_PATH" \
    --descriptor_set_out="$OUTPUT_DIR/${name}.pb" \
    "$proto"
  echo "Generated: $OUTPUT_DIR/${name}.pb"
done

echo "Done. $(echo "${PROTOS[@]}" | wc -w | tr -d ' ') descriptor files generated."
