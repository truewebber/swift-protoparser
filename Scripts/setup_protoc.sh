#!/bin/bash

# Script to set up a reference protoc environment for testing and comparison

# Exit on error
set -e

# Create Scripts directory if it doesn't exist
mkdir -p Scripts

# Create directory for protoc
mkdir -p Tools/protoc

# Determine OS
PLATFORM=$(uname -s)
ARCH=$(uname -m)

# Set protoc version
PROTOC_VERSION="25.1"

# Download and install protoc based on platform
if [ "$PLATFORM" == "Darwin" ]; then
    if [ "$ARCH" == "arm64" ]; then
        PROTOC_ZIP="protoc-${PROTOC_VERSION}-osx-aarch_64.zip"
    else
        PROTOC_ZIP="protoc-${PROTOC_VERSION}-osx-x86_64.zip"
    fi
elif [ "$PLATFORM" == "Linux" ]; then
    PROTOC_ZIP="protoc-${PROTOC_VERSION}-linux-x86_64.zip"
else
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi

echo "Downloading protoc $PROTOC_VERSION for $PLATFORM $ARCH..."
curl -OL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/${PROTOC_ZIP}"

echo "Extracting protoc..."
unzip -o "$PROTOC_ZIP" -d Tools/protoc
rm "$PROTOC_ZIP"

echo "Setting up test proto files..."
mkdir -p TestProtos

# Create a simple test proto file
cat > TestProtos/simple.proto << EOF
syntax = "proto3";

package test;

message Simple {
  string name = 1;
  int32 id = 2;
  bool active = 3;
}
EOF

# Create a more complex test proto file with services, options, and extensions
cat > TestProtos/complex.proto << EOF
syntax = "proto3";

package test;

//import "google/protobuf/descriptor.proto";
import "simple.proto";

//extend google.protobuf.FieldOptions {
//  string custom_option = 50000;
//}

message Complex {
  //string name = 1 [(custom_option) = "test"];
  string name = 1;
  repeated int32 numbers = 2;
  map<string, string> attributes = 3;
  
  enum Status {
    UNKNOWN = 0;
    ACTIVE = 1;
    INACTIVE = 2;
  }
  
  Status status = 4;
  
  message Nested {
    string value = 1;
  }
  
  Nested nested = 5;
  
  reserved 6, 8 to 10;
  reserved "foo", "bar";
}

service TestService {
  rpc GetComplex(Simple) returns (Complex);
  rpc StreamComplex(Simple) returns (stream Complex);
  rpc ProcessComplex(stream Complex) returns (Simple);
  rpc BidirectionalStream(stream Simple) returns (stream Complex);
}
EOF

echo "Generating reference descriptors with protoc..."
Tools/protoc/bin/protoc --descriptor_set_out=TestProtos/simple.pb TestProtos/simple.proto
Tools/protoc/bin/protoc --descriptor_set_out=TestProtos/complex.pb --proto_path=TestProtos TestProtos/complex.proto

echo "Setup complete!"
echo "Reference protoc binary: Tools/protoc/bin/protoc"
echo "Reference proto files: TestProtos/"
echo "Reference descriptor files: TestProtos/simple.pb, TestProtos/complex.pb" 