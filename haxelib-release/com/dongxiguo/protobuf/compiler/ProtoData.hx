// Copyright (c) 2013, 杨博 (Yang Bo)
// All rights reserved.
//
// Author: 杨博 (Yang Bo) <pop.atry@gmail.com>
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name of the <ORGANIZATION> nor the names of its contributors
//   may be used to endorse or promote products derived from this software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

package com.dongxiguo.protobuf.compiler;
import com.dongxiguo.protobuf.Error;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.EnumDescriptorProto;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.EnumValueDescriptorProto;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.DescriptorProto;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.ServiceDescriptorProto;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.FileDescriptorSet;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.FileDescriptorProto;
import com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.FieldDescriptorProto;
import haxe.io.BytesData;
import haxe.io.BytesOutput;
import haxe.macro.Expr;
import haxe.Int64;
import haxe.macro.Context;
import haxe.macro.ExprTools;
import haxe.PosInfos;
using StringTools;
#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<Value> = Hash<Value>;
#end
private typedef ProtobufType = com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.fieldDescriptorProto.Type;
/**
 * @author 杨博
 */
@:final class ProtoData
{

  /**
    The key of this map is fully qualified type name, which starts with a dot.
  **/
  public var messages(default, null):ReadonlyStringMap<DescriptorProto>;

  /**
    The key of this map is fully qualified type name, which starts with a dot.
  **/
  public var enums(default, null):ReadonlyStringMap<EnumDescriptorProto>;

  /**
    The key of this map is fully qualified package name,
    which does NOT start with a dot.
    For global package, the key is a string with zero length.
  **/
  public var packages(default, null):ReadonlyStringMap<Iterable<FileDescriptorProto>>;

  public function new(fileDescriptorSet:FileDescriptorSet)
  {
    var messageMap = new StringMap<DescriptorProto>();
    var enumMap = new StringMap<EnumDescriptorProto>();
    var packageMap = new StringMap<Array<FileDescriptorProto>>();
    this.messages = messageMap;
    this.enums = enumMap;
    this.packages = packageMap;
    function addNestedMessagesAndEnums(prefix:String, messages:Iterable<DescriptorProto>):Void
    {
      for (message in messages)
      {
        var fullName = prefix + message.name;
        messageMap.set(fullName, message);
        var nestedPrefix = fullName + ".";
        for (p in message.enumType)
        {
          enumMap.set(nestedPrefix + p.name, p);
        }
        addNestedMessagesAndEnums(nestedPrefix, message.nestedType);
      }
    }

    for (file in fileDescriptorSet.file)
    {
      {
        var packageString = file.package_;
        if (packageString == null)
        {
          packageString = "";
        }
        var array = packageMap.get(packageString);
        if (array == null)
        {
          array = [];
          packageMap.set(packageString, array);
        }
        array.push(file);
      }
      {
        var prefix = file.package_ == null ? "." : '.${file.package_}.';
        for (p in file.enumType)
        {
          enumMap.set(prefix + p.name, p);
        }
        addNestedMessagesAndEnums(prefix, file.messageType);
      }
    }

    // TODO: Extension

    //function addNestedExtensions(prefix:String, messages:Iterable<DescriptorProto>):Void
    //{
      //for (message in messages)
      //{
        //var fullName = prefix + message.name;
        //var nestedPrefix = fullName + ".";
        //for (p in message.extension)
        //{
          //var extendee = resolve(messageMap, fullName, p.extendee);
          //var a = extensionMap.get(extendee);
          //if (a == null)
          //{
            //a = [];
            //extensionMap.set(extendee, a);
          //}
          //a.push(NESTED_EXTENSION(fullName, p));
        //}
        //addNestedExtensions(nestedPrefix, message.nestedType);
      //}
    //}
    //for (file in fileDescriptorSet.file)
    //{
      //var prefix = '.${file.package_}.';
      //for (p in file.extension)
      //{
        //var extendee = resolve(messageMap, file.package_, p.extendee);
        //var a = extensionMap.get(extendee);
        //if (a == null)
        //{
          //a = [];
          //extensionMap.set(extendee, a);
        //}
        //a.push(GLOBAL_EXTENSION(file.package_, p));
      //}
      //addNestedExtensions(prefix, file.messageType);
    //}
  }

  @:noUsing
  public static function resolve<ProtoData>(map:ReadonlyStringMap<ProtoData>, from:String, path:String):String
  {
    if (path.startsWith("."))
    {
      if (map.exists(path))
      {
        return path;
      }
      else
      {
        return throw 'Cannot find out absolute type $path.';
      }
    }
    else
    {
      while (from != "")
      {
        var result = '$from.$path';
        if (map.exists(result))
        {
          return result;
        }
        else
        {
          from = from.substring(0, from.lastIndexOf("."));
        }
      }
      return throw 'Cannot find out relative type $path from $from.';
    }
  }

  @:noUsing
  public static function makeDefaultValueExpr(
    enclosingMessage:String,
    field:FieldDescriptorProto,
    enumMap:ReadonlyStringMap<EnumDescriptorProto>,
    nameConverter:NameConverter.EnumNameConverter):Expr
  {
    switch (field.type)
    {
      case ProtobufType.TYPE_BYTES:
      {
        var defaultValueStringExpr =
        {
          pos: makeMacroPosition(),
          expr: EConst(CString(field.defaultValue)),
        };
        return macro com.dongxiguo.protobuf.compiler.Parser.parseBytes($defaultValueStringExpr);
      }
      case ProtobufType.TYPE_ENUM:
      {
        var typeName = resolve(enumMap, enclosingMessage, field.typeName);
        var haxeNameParts = nameConverter.getHaxePackage(field.typeName);
        haxeNameParts.push(nameConverter.getHaxeEnumName(field.typeName));
        haxeNameParts.push(nameConverter.toHaxeEnumConstructorName(field.defaultValue));
        return ExprTools.toFieldExpr(haxeNameParts);
      }
      case ProtobufType.TYPE_INT64, TYPE_UINT64, TYPE_FIXED64, TYPE_SFIXED64, TYPE_SINT64:
      {
        var defaultValueStringExpr =
        {
          pos: makeMacroPosition(),
          expr: EConst(CString(field.defaultValue)),
        };
        return macro com.dongxiguo.protobuf.compiler.Parser.parseInt64($defaultValueStringExpr);
      }
      case ProtobufType.TYPE_INT32, ProtobufType.TYPE_SFIXED32, ProtobufType.TYPE_SINT32:
      {
        return
        {
          pos: makeMacroPosition(),
          expr: EConst(CInt(field.defaultValue)),
        };
      }
      case ProtobufType.TYPE_UINT32, ProtobufType.TYPE_FIXED32:
      {
        // 不能使用EConst(CInt(field.defaultValue))，因为可能会溢出。
        var valueExpr =
        {
          pos: makeMacroPosition(),
          expr: EConst(CFloat(field.defaultValue)),
        };
        return
        {
          pos: makeMacroPosition(),
          expr: ECheckType(
            if (Context.defined("cpp"))
            {
              // Workaround https://github.com/HaxeFoundation/haxe/issues/2174
              macro cast com.dongxiguo.protobuf.compiler.Parser.reformatFloatLiteral($valueExpr);
            }
            else
            {
              macro cast $valueExpr;
            },
            TPath(
              {
                pack: [ "com", "dongxiguo", "protobuf" ],
                name: "Types",
                sub: Type.enumConstructor(field.type),
                params: [],
              })),
        };
      }
      case ProtobufType.TYPE_BOOL:
      {
        return
        {
          pos: makeMacroPosition(),
          expr: EConst(CIdent(field.defaultValue)),
        }
      }
      case ProtobufType.TYPE_DOUBLE, ProtobufType.TYPE_FLOAT:
      {
        return switch (field.defaultValue)
        {
          case "nan":
          {
            macro Math.NaN;
          }
          case "inf":
          {
            macro Math.POSITIVE_INFINITY;
          }
          case "-inf":
          {
            macro Math.NEGATIVE_INFINITY;
          }
          default:
          {
            pos: makeMacroPosition(),
            expr: EConst(CFloat(field.defaultValue)),
          }
        }
      }
      case ProtobufType.TYPE_STRING:
      {
        if (Context.defined("js"))
        {
          // Workaround for https://github.com/HaxeFoundation/haxe/issues/1581
          var quotedStringExpr =
          {
            pos: makeMacroPosition(),
            expr: EConst(CString(haxe.Json.stringify(field.defaultValue))),
          }
          return macro untyped __js__($quotedStringExpr);
        }
        else
        {
          return
          {
            pos: makeMacroPosition(),
            expr: EConst(CString(field.defaultValue)),
          }
        }
      }
      default:
      {
        throw '${field.type} must not have default value';
      }
    }
  }

  public function getRealEnumClassDefinition(
    fullName:String,
    enumParserNameConverter:NameConverter.UtilityNameConverter,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    var haxeEnumName = enumNameConverter.getHaxeEnumName(fullName);
    var haxeEnumPackage = enumNameConverter.getHaxePackage(fullName);
    var enumPackageExpr = ExprTools.toFieldExpr(haxeEnumPackage);
    var enumExpr = macro $enumPackageExpr.$haxeEnumName;

    var valueOfCases =
    [
      for (value in this.enums.get(fullName).value)
      {
        var constructorName = enumNameConverter.toHaxeEnumConstructorName(value.name);
        {
          guard: null,
          values:
          [
            {
              pos: makeMacroPosition(),
              expr: EConst(CInt(Std.string(value.number))),
            }
          ],
          expr: macro { $enumExpr.$constructorName; },
        }
      }
    ];

    var getNumberCases =
    [
      for (value in this.enums.get(fullName).value)
      {
        var constructorName = enumNameConverter.toHaxeEnumConstructorName(value.name);
        {
          guard: null,
          values: [ macro $enumExpr.$constructorName, ],
          expr:
          {
            pos: makeMacroPosition(),
            expr: EConst(CInt(Std.string(value.number))),
          },
        }
      }
    ];

    return
    {
      pack: enumParserNameConverter.getHaxePackage(fullName),
      name: enumParserNameConverter.getHaxeClassName(fullName),
      pos: makeMacroPosition(),
      meta: [],
      params: [],
      isExtern: false,
      kind: TDClass(),
      fields:
      [
        {
          name: "getNumber",
          access: [ AStatic, APublic ],
          meta: [],
          pos: makeMacroPosition(),
          kind: FFun(
            {
              args:
              [
                {
                  name: "enumValue",
                  opt: false,
                  type: TPath(
                    {
                      pack: haxeEnumPackage,
                      name: haxeEnumName,
                      params: [],
                    }),
                }
              ],
              ret: TPath(
                {
                  pack: [],
                  name: "StdTypes",
                  sub: "Int",
                  params: [],
                }),
              expr:
              {
                pos: makeMacroPosition(),
                expr: EReturn(
                  {
                    pos: makeMacroPosition(),
                    expr: ESwitch(macro enumValue, getNumberCases, null),
                  }),
              },
              params: [],
            }),
        },
        {
          name: "valueOf",
          access: [ AStatic, APublic ],
          meta: [],
          pos: makeMacroPosition(),
          kind: FFun(
            {
              args:
              [
                {
                  name: "number",
                  opt: false,
                  type: TPath(
                    {
                      pack: [],
                      name: "StdTypes",
                      sub: "Int",
                      params: [],
                    }),
                }
              ],
              ret: TPath(
                {
                  pack: haxeEnumPackage,
                  name: haxeEnumName,
                  params: [],
                }),
              expr:
              {
                pos: makeMacroPosition(),
                expr: EReturn(
                  {
                    pos: makeMacroPosition(),
                    expr: ESwitch(
                      macro number,
                      valueOfCases,
                      macro { throw "Unknown enum value: " + number; } ),
                  }),
              },
              params: [],
            }),
        }
      ],
    };

  }


  public function getFakeEnumClassDefinition(
    fullName:String,
    enumClassNameConverter:NameConverter.UtilityNameConverter,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    var enumProto = enums.get(fullName);
    var fields:Array<Field> = [];
    for (value in enumProto.value)
    {
      fields.push(
        {
          access: [ AStatic, APublic, ],
          pos: makeMacroPosition(),
          name: enumNameConverter.toHaxeEnumConstructorName(value.name),
          kind: FProp(
            "default", "never",
            null,
            {
              pos: makeMacroPosition(),
              expr: EConst(CInt(Std.string(value.number))),
            }),
        });
    }

    var enumPackage = enumNameConverter.getHaxePackage(fullName);
    var enumName = enumNameConverter.getHaxeEnumName(fullName);
    var nativeName = enumPackage.concat([enumName]).join(".");
    fields.push(
      {
        name: "valueOf",
        access: [ AStatic, APublic ],
        meta: [],
        pos: makeMacroPosition(),
        kind: FFun(
          {
            args:
            [
              {
                name: "number",
                opt: false,
                type: TPath(
                  {
                    pack: [],
                    name: "StdTypes",
                    sub: "Int",
                    params: [],
                  }),
              }
            ],
            ret: TPath(
              {
                pack: enumPackage,
                name: enumName,
                params: [],
              }),
            expr: macro return cast number,
            params: [],
          }),
      });
    fields.push(
      {
        name: "getNumber",
        access: [ AStatic, APublic ],
        meta: [],
        pos: makeMacroPosition(),
        kind: FFun(
          {
            args:
            [
              {
                name: "enumValue",
                opt: false,
                type: TPath(
                  {
                    pack: enumPackage,
                    name: enumName,
                    params: [],
                  }),
              }
            ],
            ret: TPath(
              {
                pack: [],
                name: "StdTypes",
                sub: "Int",
                params: [],
              }),
            expr: macro return cast enumValue,
            params: [],
          }),
      });
    return
    {
      pack: enumClassNameConverter.getHaxePackage(fullName),
      name: enumClassNameConverter.getHaxeClassName(fullName),
      pos: makeMacroPosition(),
      meta: [{
          name: ":native",
          pos: makeMacroPosition(),
          params:
          [
            {
              pos: makeMacroPosition(),
              expr: EConst(CString(nativeName)),
            }
          ],
        }],
      params: [],
      isExtern: false,
      kind: TDClass(),
      fields: fields,
    };
  }

  macro static function makeMacroPosition():ExprOf<Position>
  {
    var positionExpr = Context.makeExpr(Context.getPosInfos(Context.currentPos()), Context.currentPos());
    if (haxe.macro.Context.defined("macro"))
    {
      return macro haxe.macro.Context.makePosition($positionExpr);
    }
    else
    {
      return positionExpr;
    }
  }

  function getEnumDefinition(
    fullName:String,
    enumNameConverter:NameConverter.EnumNameConverter,
    fakeEnumBehavior:FakeEnumBehavior):TypeDefinition
  {
    var fields:Array<Field> = [];
    var enumProto = enums.get(fullName);
    for (value in enumProto.value)
    {
      fields.push(
        {
          access: [],
          pos: makeMacroPosition(),
          name: enumNameConverter.toHaxeEnumConstructorName(value.name),
          kind: FVar(null),
        });
    }
    var isFakeEnum = switch (fakeEnumBehavior)
    {
      case FakeEnumBehavior.ALWAYS: true;
      case FakeEnumBehavior.NEVER: false;
      case FakeEnumBehavior.ALLOW_ALIAS_ONLY:
      {
        enumProto.options == null || enumProto.options.allowAlias;
      }
    }
    return
    {
      pack: enumNameConverter.getHaxePackage(fullName),
      name: enumNameConverter.getHaxeEnumName(fullName),
      pos: makeMacroPosition(),
      meta: isFakeEnum ?
      [
        {
          name: ":fakeEnum",
          pos: makeMacroPosition(),
          params: [ macro StdTypes.Int ],
        }
      ] : [],
      params: [],
      isExtern: isFakeEnum,
      kind: TDEnum,
      fields: fields,
    };
  }

  public function getFakeEnumDefinition(
    fullName:String,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    return getEnumDefinition(fullName, enumNameConverter, FakeEnumBehavior.ALWAYS);
  }

  public function getRealEnumDefinition(
    fullName:String,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    return getEnumDefinition(fullName, enumNameConverter, FakeEnumBehavior.NEVER);
  }

  function getMessageDefinition(
    fullName:String,
    messageNameConverter:NameConverter.MessageNameConverter,
    enumNameConverter:NameConverter.EnumNameConverter,
    readonly:Bool):TypeDefinition
  {
    function toHaxeType(
      protoType:com.dongxiguo.protobuf.compiler.bootstrap.google.protobuf.fieldDescriptorProto.Type,
      protoTypeName:Null<String>):ComplexType
    {
      switch (protoType)
      {
        case ProtobufType.TYPE_ENUM:
        {
          var fullyQualifiedName = resolve(enums, fullName, protoTypeName);
          return TPath(
          {
            params: [],
            name: enumNameConverter.getHaxeEnumName(fullyQualifiedName),
            pack: enumNameConverter.getHaxePackage(fullyQualifiedName),
          });
        }
        case ProtobufType.TYPE_MESSAGE:
        {
          var fullyQualifiedName = resolve(messages, fullName, protoTypeName);
          return TPath(
          {
            params: [],
            name: messageNameConverter.getHaxeClassName(fullyQualifiedName),
            pack: messageNameConverter.getHaxePackage(fullyQualifiedName),
          });
        }
        default:
        {
          return TPath(
          {
            params: [],
            sub: Type.enumConstructor(protoType),
            name: "Types",
            pack: [ "com", "dongxiguo", "protobuf" ],
          });
        }
      }
    }
    var fields:Array<Field> = [
      {
        name: "unknownFields",
        access: [ APublic ],
        pos: makeMacroPosition(),
        meta:
        [
          {
            name: ":optional",
            params: [],
            pos: makeMacroPosition(),
          },
        ],
        kind: FProp(
          "default",
          readonly ? "null" : "default",
           TPath(
              {
                pack: [ "com", "dongxiguo", "protobuf", "unknownField" ],
                name: readonly ? "ReadonlyUnknownFieldMap" : "UnknownFieldMap",
                params: [],
              })),
      }];
    var messageProto = messages.get(fullName);
    var constructorBlock = [];
    for (field in messageProto.field)
    {
      if (field.type == TYPE_GROUP)
      {
        #if neko
        Context.warning("TYPE_GROUP is unsupported!", makeMacroPosition());
        {
          pos: makeMacroPosition(),
          expr: EBlock([]),
        }
        #else
        trace("TYPE_GROUP is unsupported!");
        #end
        continue;
      }
      var haxeFieldName = messageNameConverter.toHaxeFieldName(field.name);
      switch (field)
      {
        case { label: LABEL_REQUIRED, defaultValue: defaultValueString, } :
        {
          fields.push(
          {
            name: haxeFieldName,
            pos: makeMacroPosition(),
            access: [APublic],
            kind: FProp("default", readonly ? "null" : "default", toHaxeType(field.type, field.typeName)),
          });
          if (defaultValueString != null && !readonly)
          {
            var defaultValueExpr = makeDefaultValueExpr(fullName, field, enums, enumNameConverter);
            constructorBlock.push(macro this.$haxeFieldName = $defaultValueExpr);
          }
        }
        case { label: LABEL_OPTIONAL, defaultValue: defaultValueString, } :
        {
          if (defaultValueString == null)
          {
            fields.push(
            {
              meta: [ { params: [], pos: makeMacroPosition(), name: ":optional", }, ],
              name: haxeFieldName,
              pos: makeMacroPosition(),
              access: [ APublic ],
              kind: FProp("default", readonly ? "null" : "default", TPath(
                {
                  pack: [],
                  name: "StdTypes",
                  sub: "Null",
                  params: [TPType(toHaxeType(field.type, field.typeName))],
                })),
            });
          }
          else
          {
            var getterName = "get_" + haxeFieldName;
            var setterName = "set_" + haxeFieldName;
            if (!readonly)
            {
              var defaultFieldName = "__default_" + haxeFieldName;
              var haxeFieldExpr =
              {
                pos: makeMacroPosition(),
                expr: EConst(CIdent(haxeFieldName)),
              }
              fields.push(
              {
                name: defaultFieldName,
                pos: makeMacroPosition(),
                access: [ AStatic ],
                kind: FProp("null", "never",
                  TPath(
                  {
                    pack: [],
                    name: "StdTypes",
                    sub: "Null",
                    params: [TPType(toHaxeType(field.type, field.typeName))],
                  }),
                  makeDefaultValueExpr(fullName, field, enums, enumNameConverter)),
              });
              var defaultFieldExpr =
              {
                pos: makeMacroPosition(),
                expr: EConst(CIdent(defaultFieldName)),
              }

              fields.push(
              {
                name: setterName,
                access: [ AInline ],
                pos: makeMacroPosition(),
                kind: FFun(
                {
                  ret: null,
                  params: [],
                  args: [ { name: "value", opt: false, type: null }, ],
                  expr: macro { return $haxeFieldExpr = value; },
                }),
              });
              fields.push(
              {
                name: getterName,
                access: [ AInline ],
                pos: makeMacroPosition(),
                kind: FFun(
                {
                  ret: null,
                  params: [],
                  args: [],
                  expr: macro
                  if ($haxeFieldExpr != null)
                  {
                    return $haxeFieldExpr;
                  }
                  else
                  {
                    return $defaultFieldExpr;
                  }
                }),
              });
            }
            fields.push(
            {
              name: haxeFieldName,
              pos: makeMacroPosition(),
              access: [ APublic ],
              meta: [ { name: ":isVar", params: [], pos: makeMacroPosition(), }, ],
              kind: FProp(
                getterName,
                setterName,
                TPath(
                  {
                    pack: [],
                    name: "StdTypes",
                    sub: "Null",
                    params: [TPType(toHaxeType(field.type, field.typeName))],
                  })),
            });
          }
        }
        case { label: LABEL_REPEATED } :
        {
          fields.push(
          {
            name: haxeFieldName,
            pos: makeMacroPosition(),
            access: [APublic],
            kind: FProp("default", readonly ? "null" : "default", TPath(
              {
                pack: [],
                name: readonly ? "Iterable" : "Array",
                params: [TPType(toHaxeType(field.type, field.typeName))],
              })),
          });
          if (!readonly)
          {
            constructorBlock.push(macro this.$haxeFieldName = []);
          }
        }
      }
    }
    if (!readonly)
    {
      fields.push(
        {
          name: "new",
          pos: makeMacroPosition(),
          access: [ APublic ],
          kind: FFun(
          {
            ret: null,
            params: [],
            args: [],
            expr:
            {
              expr: EBlock(constructorBlock),
              pos: makeMacroPosition(),
            }
          })
        });
    }
    return
    {
      pack: messageNameConverter.getHaxePackage(fullName),
      name: messageNameConverter.getHaxeClassName(fullName),
      pos: makeMacroPosition(),
      meta: [],
      params: [],
      isExtern: false,
      kind: readonly ? TDStructure : TDClass(),
      fields: fields,
    };
  }

  public function getReadonlyMessageDefinition(
    fullName:String,
    readonlyNameConverter:NameConverter.MessageNameConverter,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    return getMessageDefinition(
      fullName,
      readonlyNameConverter,
      enumNameConverter,
      true);
  }

  public function getBuilderDefinition(
    fullName:String,
    builderNameConverter:NameConverter.MessageNameConverter,
    enumNameConverter:NameConverter.EnumNameConverter):TypeDefinition
  {
    return getMessageDefinition(
      fullName,
      builderNameConverter,
      enumNameConverter,
      false);
  }

}

typedef ReadonlyStringMap<Element> =
{
  function iterator():Iterator<Element>;
  function exists(key:String):Bool;
  function get(key:String):Null<Element>;
  function keys():Iterator<String>;
}

/** Determine whether a enum from a proto file should be [@:fakeEnum]. */
private enum FakeEnumBehavior
{

  /** Every enums in proto packages must be [@:fakeEnum] */
  ALWAYS;

  /** Every enums in proto packages must not be [@:fakeEnum] */
  NEVER;

  /**
    If a enum's allowAlias option is set to true,
    then enum must be [@:fakeEnum].
    Otherwise, the enum must not be [@:fakeEnum].
  **/
  ALLOW_ALIAS_ONLY;

}
