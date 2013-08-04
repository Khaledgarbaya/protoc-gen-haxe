package com.dongxiguo.protobuf;

import com.dongxiguo.protobuf.binaryFormat.ZigZag;
import haxe.ds.IntMap;
import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

/**
  @author 杨博
**/
typedef UnknownFieldMap = IntMap<UnknownField>;

typedef ReadonlyUnknownFieldMap =
{

  function iterator():Iterator<UnknownField>;

  function exists(key:Int):Bool;

  function get(key:Int):Null<UnknownField>;

  function keys():Iterator<Int>;

}

abstract UnknownField(Dynamic) from Array<UnknownFieldElement> from Null<UnknownFieldElement>
{

  public static inline function fromOptional(value:Null<UnknownFieldElement>):UnknownField
  {
    return value;
  }

  public static inline function fromRepeated(value:Array<UnknownFieldElement>):UnknownField
  {
    return value;
  }

  public function toRepeated():Array<UnknownFieldElement>
  {
    if (this == null)
    {
      return [];
    }
    else if (Std.is(this, Array))
    {
      return this;
    }
    else
    {
      return [ this ];
    }
  }

  public function toOptional():Null<UnknownFieldElement>
  {
    if (this == null)
    {
      return null;
    }
    else if (Std.is(this, Array))
    {
      switch (cast(this, Array<Dynamic>))
      {
        case []: return null;
        case [ singleElement ]: return singleElement;
        default: throw Error.DuplicatedValueForNonRepeatedField;
      }
    }
    else
    {
      return this;
    }
  }

}

abstract UnknownFieldElement(Dynamic)
from VarintUnknownField
from Fixed32BitUnknownField
from Fixed64BitUnknownField
from LengthDelimitedUnknownField
{

  public inline function toVarint():VarintUnknownField
  {
    return this;
  }

  public inline function toFixed32Bit():Fixed32BitUnknownField
  {
    return this;
  }

  public inline function toLengthDelimited():LengthDelimitedUnknownField
  {
    return this;
  }

  public inline function toFixed64Bit():Fixed64BitUnknownField
  {
    return this;
  }

}

abstract VarintUnknownField(Int64) from Int64 to Int64
{
  public static inline function fromBool(value:Types.TYPE_BOOL):VarintUnknownField
  {
    return value ? Int64.make(0, 1) : Int64.make(0, 0);
  }

  public inline function toBool():Types.TYPE_BOOL
  {
    switch ([ Int64.getHigh(this), Int64.getLow(this) ])
    {
      case [ 0, 1 ]: return true;
      case [ 0, 0 ]: return false;
      default: throw Error.MalformedBoolean;
    }
  }

  public static inline function fromInt32(value:Types.TYPE_INT32):VarintUnknownField
  {
    return Int64.make(0, value);
  }

  public inline function toInt32():Types.TYPE_INT32
  {
    return Int64.getLow(this);
  }

  public static inline function fromSint32(value:Types.TYPE_INT32):VarintUnknownField
  {
    return Int64.make(0, ZigZag.encode32(value));
  }

  public inline function toSint32():Types.TYPE_SINT32
  {
    return ZigZag.decode32(Int64.getLow(this));
  }

  public static inline function fromSint64(value:Types.TYPE_SINT64):VarintUnknownField
  {
    #if haxe3
    var low = Types.TYPE_INT64.getLow(value);
    var high = Types.TYPE_INT64.getLow(value);
    #else
    var low = Int32.toNativeInt(Types.TYPE_INT64.getLow(value));
    var high = Int32.toNativeInt(Types.TYPE_INT64.getLow(value));
    #end
    var transformedLow = ZigZag.encode64low(low, high);
    var transformedHigh = ZigZag.encode64high(low, high);
    #if haxe3
    return Types.TYPE_FIXED64.make(transformedLow, transformedHigh);
    #else
    return Types.TYPE_FIXED64.make(Int32.ofInt(transformedLow), Int32.ofInt(transformedHigh));
    #end
  }

  public inline function toSint64():Types.TYPE_SINT64
  {
    var beforeTransform = this;
    #if haxe3
    var low = Types.TYPE_INT64.getLow(beforeTransform);
    var high = Types.TYPE_INT64.getLow(beforeTransform);
    #else
    var low = Int32.toNativeInt(Types.TYPE_INT64.getLow(beforeTransform));
    var high = Int32.toNativeInt(Types.TYPE_INT64.getLow(beforeTransform));
    #end
    var transformedLow = ZigZag.decode64low(low, high);
    var transformedHigh = ZigZag.decode64high(low, high);
    #if haxe3
    return Types.TYPE_FIXED64.make(transformedLow, transformedHigh);
    #else
    return Types.TYPE_FIXED64.make(Int32.ofInt(transformedLow), Int32.ofInt(transformedHigh));
    #end
  }

  public static inline function fromUint32(value:Types.TYPE_UINT32):VarintUnknownField
  {
    return Int64.make(0, value);
  }

  public inline function toUint32():Types.TYPE_UINT32
  {
    return Int64.getLow(this);
  }

  public static inline function fromInt64(value:Types.TYPE_INT64):VarintUnknownField
  {
    return value;
  }

  public inline function toInt64():Types.TYPE_INT64
  {
    return this;
  }

  public static inline function fromUint64(value:Types.TYPE_UINT64):VarintUnknownField
  {
    return value;
  }

  public inline function toUint64():Types.TYPE_UINT64
  {
    return this;
  }
}

abstract Fixed32BitUnknownField(Bytes) from Bytes to Bytes
{


  public static inline function fromFloat(value:Types.TYPE_FLOAT):Fixed32BitUnknownField
  {
    var output = new BytesOutput();
    output.writeFloat(value);
    return output.getBytes();
  }

  public static inline function fromFixed32(value:Types.TYPE_FIXED32):Fixed32BitUnknownField
  {
    var output = new BytesOutput();
    output.writeInt32(value);
    return output.getBytes();
  }

  public static inline function fromSfixed32(value:Types.TYPE_SFIXED32):Fixed32BitUnknownField
  {
    var output = new BytesOutput();
    output.writeInt32(value);
    return output.getBytes();
  }

  public inline function toFloat():Types.TYPE_FLOAT
  {
    return new BytesInput(this).readFloat();
  }

  public inline function toFixed32():Types.TYPE_FIXED32
  {
    var input = new BytesInput(this);
    return input.readInt32();
  }

  public inline function toSfixed32():Types.TYPE_SFIXED32
  {
    var input = new BytesInput(this);
    return input.readInt32();
  }

}

abstract Fixed64BitUnknownField(Bytes) from Bytes to Bytes
{

  public static inline function fromDouble(value:Types.TYPE_DOUBLE):Fixed64BitUnknownField
  {
    var output = new BytesOutput();
    output.writeDouble(value);
    return output.getBytes();
  }

  public static inline function fromFixed64(value:Types.TYPE_FIXED64):Fixed64BitUnknownField
  {
    var output = new BytesOutput();
    output.writeInt32(Types.TYPE_FIXED64.getLow(value));
    output.writeInt32(Types.TYPE_FIXED64.getHigh(value));
    return output.getBytes();
  }

  public static inline function fromSfixed64(value:Types.TYPE_SFIXED64):Fixed64BitUnknownField
  {
    var output = new BytesOutput();
    output.writeInt32(Types.TYPE_SFIXED64.getLow(value));
    output.writeInt32(Types.TYPE_SFIXED64.getHigh(value));
    return output.getBytes();
  }

  public inline function toDouble():Types.TYPE_DOUBLE
  {
    return new BytesInput(this).readDouble();
  }

  public inline function toFixed64():Types.TYPE_FIXED64
  {
    var input = new BytesInput(this);
    var low = input.readInt32();
    var high = input.readInt32();
    return Types.TYPE_FIXED64.make(high, low);
  }

  public inline function toSfixed64():Types.TYPE_SFIXED64
  {
    var input = new BytesInput(this);
    var low = input.readInt32();
    var high = input.readInt32();
    return Types.TYPE_SFIXED64.make(high, low);
  }

}

abstract LengthDelimitedUnknownField(Bytes) from Bytes to Bytes
{

  public static inline function fromString(value:Types.TYPE_STRING):LengthDelimitedUnknownField
  {
    return Bytes.ofString(value);
  }

  public static inline function fromBytes(value:Types.TYPE_BYTES):LengthDelimitedUnknownField
  {
    return value;
  }

  public inline function toString():Types.TYPE_STRING
  {
    return this.toString();
  }

  public inline function toBytes():Types.TYPE_BYTES
  {
    return this;
  }

}
