// proto-unlinked-gen parses .proto files through protocompile WITHOUT the linking stage.
// Custom options remain as uninterpreted_option with fully populated NameParts — the same
// representation that SwiftProtoParser produces.
//
// Usage:
//
//	proto-unlinked-gen -o out.pb file.proto [file2.proto ...]
//
// No -I flag is needed: parser.Parse is purely syntactic and does not resolve imports.
// Linking (and with it type resolution for options) is intentionally skipped.
//
// The output is a binary-encoded google.protobuf.FileDescriptorSet written to -o.
// One FileDescriptorProto per input file is included (no transitive dependencies).
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/bufbuild/protocompile/parser"
	"github.com/bufbuild/protocompile/reporter"
	"google.golang.org/protobuf/proto"
	descriptorpb "google.golang.org/protobuf/types/descriptorpb"
)

func main() {
	outputPath := flag.String("o", "", "Output path for the binary FileDescriptorSet (.pb)")
	flag.Parse()

	protoFiles := flag.Args()
	if *outputPath == "" || len(protoFiles) == 0 {
		fmt.Fprintf(os.Stderr, "Usage: proto-unlinked-gen -o out.pb file.proto [file2.proto ...]\n")
		os.Exit(1)
	}

	fds := &descriptorpb.FileDescriptorSet{}

	for _, protoPath := range protoFiles {
		fdp, err := parseUnlinked(protoPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error parsing %s: %v\n", protoPath, err)
			os.Exit(1)
		}
		fds.File = append(fds.File, fdp)
	}

	out, err := proto.Marshal(fds)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error marshaling FileDescriptorSet: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(*outputPath, out, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "error writing %s: %v\n", *outputPath, err)
		os.Exit(1)
	}
}

// parseUnlinked parses a single .proto file into an unlinked FileDescriptorProto.
// The descriptor contains uninterpreted_option entries for all custom options with
// fully populated name/NamePart arrays — no type resolution is performed.
func parseUnlinked(protoPath string) (*descriptorpb.FileDescriptorProto, error) {
	src, err := os.ReadFile(protoPath)
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	// Use the base name as the logical proto file name.
	// For files inside a known root, a caller may prefix the path; we use the
	// full relative path when the caller passes it explicitly as the file argument.
	fileName := protoPath
	// Strip leading "./" if present so the name matches standard proto conventions.
	fileName = strings.TrimPrefix(fileName, "./")

	var parseErr error
	errHandler := reporter.NewHandler(reporter.NewReporter(
		func(err reporter.ErrorWithPos) error {
			parseErr = err
			return err
		},
		func(reporter.ErrorWithPos) {},
	))

	fileAST, err := parser.Parse(fileName, strings.NewReader(string(src)), errHandler)
	if err != nil || parseErr != nil {
		if parseErr != nil {
			return nil, fmt.Errorf("parse error: %w", parseErr)
		}
		return nil, fmt.Errorf("parse error: %w", err)
	}

	// ResultFromAST converts the AST to an unlinked FileDescriptorProto.
	// The second argument (true) requests that options be preserved in their
	// uninterpreted_option form — exactly what we need.
	result, err := parser.ResultFromAST(fileAST, true, errHandler)
	if err != nil || parseErr != nil {
		if parseErr != nil {
			return nil, fmt.Errorf("descriptor conversion error: %w", parseErr)
		}
		return nil, fmt.Errorf("descriptor conversion error: %w", err)
	}

	return result.FileDescriptorProto(), nil
}
