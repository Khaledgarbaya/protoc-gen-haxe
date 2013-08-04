protoc-gen-haxe
===============

'''protoc-gen-haxe''' is the Protocol Buffers implementation in [Haxe](http://www.haxe.org/).

## Motive

I am the also author of [protoc-gen-as3](https://code.google.com/p/protoc-gen-as3/),
which is the best Protocol Buffers implementation in ActionScript 3.
But `protoc-gen-haxe` is not a port from `protoc-gen-as3`.
`protoc-gen-haxe` is very different from `protoc-gen-as3`:

| | protoc-gen-as3 | protoc-gen-haxe |
| ------------- | ------------- | ----- |
| Cross-platform | No. It only runs in Adobe Flash Player or Adobe AIR. | Yes. `protoc-gen-haxe` can run in Flash Players, browsers, servers, and even in Haxe compiler macros. |
| Run Time Type Information | Little, via native Flash API. | Yes. By parsing DescriptorProtoSet at runtime, users can access full information of `.proto`s. |
| Mutable message | Yes | Yes |
| Readonly message | No | Yes |
| Will unused code be eliminated? | No | Yes. `protoc-gen-haxe` separate different features into different classes, unused codes can be easy eliminated by the Haxe compiler. |
| Can users generate their custom code? | No. The user has to create another Protocol Buffers plugin. | Yes. The user can use `protoc-gen-haxe` API in Haxe macro |
| Self-hosting | No. `protoc-gen-as3`'s compiler is written in Java. | Yes. Both compiler and runtime library of `protoc-gen-haxe` are written in Haxe. Even [20% lines of source code](https://github.com/Atry/protoc-gen-haxe/tree/master/haxelib-release/com/dongxiguo/protobuf/compiler/bootstrap) are generated by `protoc-gen-haxe` itself! |
| Is it a protoc plugin? | Yes. `protoc-gen-as3` compiler must be launched by protoc. | No. `protoc-gen-haxe` can directly import binary format definition of `.proto` files. |

## Installation

 1. Download [protoc](https://code.google.com/p/protobuf/downloads/detail?name=protoc-2.5.0-win32.zip).
 2. Download and install [Haxe 3](http://www.haxe.org/download).
 3. ```haxelib install protoc-gen-haxe```

## Usage

### Step 1: Create `sample.proto`

```
// sample.proto

package samplePackage;

message SampleMessage {
  optional string sample_field = 1;
}
```

### Step 2: Create `SampleMain.hx`

```
// SampleMain.hx

import sys.io.File;
import sys.FileSystem;
import com.dongxiguo.protobuf.binaryFormat.BinaryFileInput;
import samplePackage.SampleMessage_Builder;
using samplePackage.SampleMessage_Merger;
using samplePackage.SampleMessage_Writer;

class SampleMain {

  static function save():Void
  {
    var builder = new SampleMessage_Builder();
    builder.sampleField = "Hello, World!";
    var output = File.write("sample.save");
    builder.writeTo(output);
    output.close();
  }

  static function load():Void
  {
    var builder = new SampleMessage_Builder();
    var input = File.read("sample.save");
    var pbInput = new BinaryFileInput(input, FileSystem.stat("sample.save").size);
    builder.mergeFrom(pbInput);
    trace('builder.sample = ${builder.sampleField}');
    input.close();
  }

  public static function main() {
    save();
    load();
  }

}
```

### Step 3: Convert `sample.proto` to binary format.

```
protoc sample.proto --descriptor_set_out=sample.proto.bin
```

### Step 4: Run!

```
haxe -lib protoc-gen-haxe --macro "com.dongxiguo.protobuf.commandLine.Importer.importDescroptorFileSet('sample.proto.bin')" -x SampleMain.hx
```

Now you see your program create `sample.save` in Protocol Buffers format, and then read this file:
