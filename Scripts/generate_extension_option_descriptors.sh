#!/usr/bin/env bash
# generate_extension_option_descriptors.sh
#
# Generates binary .pb descriptor files for HandcraftedProtos and ClientProtos.
#
# For protos WITHOUT custom extension options  → protoc (exact match with typed option fields).
# For protos WITH    custom extension options  → proto-unlinked-gen (protocompile, unlinked,
#                                                custom options remain as uninterpreted_option).
#
# Outputs are written to:
#   Tests/TestResources/HandcraftedDescriptors/
#   Tests/TestResources/ClientProtoDescriptors/
#
# Usage: bash Scripts/generate_extension_option_descriptors.sh
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HANDCRAFTED_PROTOS="$REPO_ROOT/Tests/TestResources/HandcraftedProtos"
HANDCRAFTED_DESCS="$REPO_ROOT/Tests/TestResources/HandcraftedDescriptors"
CLIENT_PROTOS="$REPO_ROOT/Tests/TestResources/ClientProtos"
CLIENT_DESCS="$REPO_ROOT/Tests/TestResources/ClientProtoDescriptors"
STDLIBS=/usr/local/include

mkdir -p "$HANDCRAFTED_DESCS" "$CLIENT_DESCS"

# ---------------------------------------------------------------------------
# Build proto-unlinked-gen Go binary
# ---------------------------------------------------------------------------
echo "==> Building proto-unlinked-gen..."
GO_TOOL_SRC="$SCRIPT_DIR/proto-unlinked-gen"
GO_TOOL_BIN="$SCRIPT_DIR/proto-unlinked-gen-bin"
(cd "$GO_TOOL_SRC" && go build -o "$GO_TOOL_BIN" .)
echo "    Built: $GO_TOOL_BIN"

# ---------------------------------------------------------------------------
# Helper: run protoc for a standard-options-only proto.
# Usage: run_protoc <output.pb> <-I path> ... <proto_file_relative_to_last_-I>
# The --include_imports flag must not appear in the extra args.
# ---------------------------------------------------------------------------
run_protoc() {
    local out="$1"; shift
    protoc --include_imports --descriptor_set_out="$out" "$@"
    echo "    protoc → $(basename "$out")"
}

# Helper: run Go tool for a custom-options proto.
run_gotool() {
    local out="$1"
    local proto_file="$2"
    "$GO_TOOL_BIN" -o "$out" "$proto_file"
    echo "    go-tool → $(basename "$out")"
}

# ---------------------------------------------------------------------------
# Handcrafted protos
# ---------------------------------------------------------------------------
echo ""
echo "==> Generating HandcraftedDescriptors..."

# Tier 1a: standard options only → protoc
run_protoc \
    "$HANDCRAFTED_DESCS/test_standard_options.pb" \
    -I "$HANDCRAFTED_PROTOS" \
    -I "$STDLIBS" \
    test_standard_options.proto

run_protoc \
    "$HANDCRAFTED_DESCS/test_ext_range_with_options.pb" \
    -I "$HANDCRAFTED_PROTOS" \
    -I "$STDLIBS" \
    test_ext_range_with_options.proto

# Tier 1b: custom extension options → Go-tool (unlinked)
for proto in \
    test_custom_options_basic.proto \
    test_subfield_path.proto \
    test_message_literal_option.proto \
    test_all_option_contexts.proto \
    test_number_option_values.proto \
    test_qualified_ext_subfield.proto \
    test_multi_options_field.proto \
    test_repeated_in_extend.proto
do
    stem="${proto%.proto}"
    run_gotool \
        "$HANDCRAFTED_DESCS/${stem}.pb" \
        "$HANDCRAFTED_PROTOS/$proto"
done

# ---------------------------------------------------------------------------
# Client protos
# ---------------------------------------------------------------------------
echo ""
echo "==> Generating ClientProtoDescriptors..."

PROTOC_FLAGS=(-I "$CLIENT_PROTOS" -I "$STDLIBS")

# Tier 1a: no custom extension options → protoc
run_protoc "$CLIENT_DESCS/book_processed_message.pb" \
    "${PROTOC_FLAGS[@]}" pubsub/book_processed.message.proto

run_protoc "$CLIENT_DESCS/loan_history_message.pb" \
    "${PROTOC_FLAGS[@]}" pubsub/loan_history.message.proto

run_protoc "$CLIENT_DESCS/catalog_changes_message.pb" \
    "${PROTOC_FLAGS[@]}" pubsub/catalog_changes.message.proto

run_protoc "$CLIENT_DESCS/health_message.pb" \
    "${PROTOC_FLAGS[@]}" pb_system/health.message.proto

run_protoc "$CLIENT_DESCS/health_service.pb" \
    "${PROTOC_FLAGS[@]}" pb_system/health.service.proto

run_protoc "$CLIENT_DESCS/public_types.pb" \
    "${PROTOC_FLAGS[@]}" pb_catalog/public_types.proto

run_protoc "$CLIENT_DESCS/book_message.pb" \
    "${PROTOC_FLAGS[@]}" pb_circulation/book.message.proto

run_protoc "$CLIENT_DESCS/book_service.pb" \
    "${PROTOC_FLAGS[@]}" pb_circulation/book.service.proto

run_protoc "$CLIENT_DESCS/summary_count.pb" \
    "${PROTOC_FLAGS[@]}" pb_analytics/summary_count.proto

# Tier 1b: custom extension options → Go-tool (unlinked)
run_gotool "$CLIENT_DESCS/gateway_message.pb" \
    "$CLIENT_PROTOS/pb_gateway/gateway.message.proto"

run_gotool "$CLIENT_DESCS/gateway_service.pb" \
    "$CLIENT_PROTOS/pb_gateway/gateway.service.proto"

echo ""
echo "==> Done. All descriptors generated."
